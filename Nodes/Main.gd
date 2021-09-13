extends Spatial

const EPSILON : float = 1e-1

onready var immGeom : ImmediateGeometry = $ImmediateGeometry
onready var pathCurve : Curve3D = $test/Path.curve
onready var pathFollow : PathFollow = $test/Path/PathFollow

func appendCurveToOtherCurve(curveToAppend : Curve3D, targetCurve : Curve3D):
	"""
	Adds the points of curveToAppend to the end of targetCurve
	"""
	var curveAppStartPos : Vector3 = curveToAppend.interpolate_baked(0.0)
	var curveAppNormal : Vector3 = curveToAppend.interpolate_baked_up_vector(0.0)
	var curveAppTang : Vector3 = (curveToAppend.interpolate_baked(EPSILON) - curveAppStartPos).normalized()
	var basisAppendStart : Basis = Basis(curveAppTang, curveAppNormal, curveAppTang.cross(curveAppNormal))
	
	var curveTargEndPos : Vector3 = targetCurve.interpolate_baked(targetCurve.get_baked_length())
	var curveTargNormal : Vector3 = targetCurve.interpolate_baked_up_vector(targetCurve.get_baked_length())
	var curveTargTang : Vector3 = (curveTargEndPos - targetCurve.interpolate_baked(targetCurve.get_baked_length() - EPSILON)).normalized()
	var basisTargEnd : Basis = Basis(curveTargTang, curveTargNormal, curveTargTang.cross(curveTargNormal))
	
	var basisTot : Basis = basisTargEnd * basisAppendStart.transposed()
	
	for pIdx in range(1, curveToAppend.get_point_count()):
		var newPointIdx : int = targetCurve.get_point_count()
		targetCurve.add_point((basisTot * (curveToAppend.get_point_position(pIdx) - curveAppStartPos)) + curveTargEndPos)
		targetCurve.set_point_in(newPointIdx, basisTot * curveToAppend.get_point_in(pIdx))
		targetCurve.set_point_out(newPointIdx, basisTot * curveToAppend.get_point_out(pIdx))

func getCurveTransform(path : Path, curveOffset : float) -> Transform:
	var curve : Curve3D = path.curve
	
	var curvePos : Vector3 = curve.interpolate_baked(curveOffset, true)
	var curveNorm : Vector3 = curve.interpolate_baked_up_vector(curveOffset, true)
	var curveZ : Vector3 = (curve.interpolate_baked(curveOffset + EPSILON, true) - curvePos).normalized()
	var curveX : Vector3 = curveZ.cross(curveNorm)
	
	return Transform(Basis(curveZ, curveNorm, curveX), curvePos)

func getTransformOfCircleAroundCurve(path : Path, curveOffset : float, circleRadius : float, circleOffset : float) -> Transform:
	"""
	Computes the Transform matrix on the circle around a point of the curve
	"""
	var curveTrans : Transform = getCurveTransform(path, curveOffset)
	
	var circleNormOffset : float = circleOffset / circleRadius
	var circleX : Vector3 = cos(circleNormOffset) * curveTrans.basis.z + sin(circleNormOffset) * curveTrans.basis.y
	var circleNormVec : Vector3 = circleX.cross(cos(circleNormOffset + 1.0) * curveTrans.basis.z + sin(circleNormOffset + 1.0) * curveTrans.basis.y).normalized()
	var circlePos : Vector3 = curveTrans.origin - circleRadius * circleX
	
	return Transform(Basis(circleNormVec, circleX, circleX.cross(circleNormVec)), circlePos)

func wrapGridmapLineAroundCurve_noDeform(gridmap : GridMap, lineXStart : int, lineXEnd : int, startCurveOffset : float, path : Path):
	
	for lineXCoordinate in range(lineXStart, lineXEnd + 1):
		var zCoord : int = 0
		var cellItemIdx : int = gridmap.get_cell_item(lineXCoordinate, 0, zCoord)
		
		var lineItemsIdx : Array = []
		while cellItemIdx != -1:
			lineItemsIdx.append(cellItemIdx)
			
			zCoord += 1
			cellItemIdx = gridmap.get_cell_item(lineXCoordinate, 0, zCoord)
		
		if lineItemsIdx.size() > 0:
			var lineAABB : AABB = AABB()
			lineAABB.position = gridmap.map_to_world(lineXStart, 0, 0) - (gridmap.cell_size / 2.0)
			lineAABB.size = Vector3(gridmap.cell_size.x, gridmap.cell_size.y, gridmap.cell_size.z * lineItemsIdx.size()) 
			
			var circleRadius : float = ((gridmap.cell_size.z / 2.0) / tan(PI / lineItemsIdx.size())) + 0.5 * gridmap.cell_size.x
			var circleSectionSize : float = TAU * circleRadius / lineItemsIdx.size()
			
			for i in range(lineItemsIdx.size()):
				var itemIdx : int = lineItemsIdx[i]
				
				var chunkMeshInst : MeshInstance = MeshInstance.new()
				$Sections.add_child(chunkMeshInst)
				
				chunkMeshInst.mesh = gridmap.mesh_library.get_item_mesh(itemIdx)
				chunkMeshInst.transform = getTransformOfCircleAroundCurve(path, startCurveOffset, circleRadius, circleSectionSize * i)
				
			startCurveOffset += lineAABB.size.x

func preprocessMeshLib(meshlib : MeshLibrary):
	"""
	Converts all elements of a mesh library to ArrayMesh objects
	"""
	for itemIdx in meshlib.get_item_list():
		meshlib.set_item_mesh(itemIdx, Utilities.convertMeshToArrayMesh(meshlib.get_item_mesh(itemIdx)))

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	$test.genNewCurve()
	Utilities.drawCurve(pathCurve, immGeom)
	
	preprocessMeshLib($GridMap.mesh_library)
	
	if true:
		var start : float = OS.get_ticks_msec()
		
		for i in range(10):
			wrapGridmapLineAroundCurve_noDeform($GridMap, 0, 8, i * $GridMap.cell_size.x * 9, $test/Path)
		
		var end : float = OS.get_ticks_msec()
		print(end - start)

#var circleOffset : float = 0.0
func _process(delta):
	pathFollow.offset += delta * 5.0
	
	#circleOffset += delta * 1.0
	#$MeshInstance.transform = getTransformOfCircleAroundCurve($test/Path, 10.0, 5.0, circleOffset)
