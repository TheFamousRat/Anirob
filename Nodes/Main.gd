extends Spatial

const EPSILON : float = 1e-3

onready var immGeom : ImmediateGeometry = $ImmediateGeometry
onready var pathCurve : Curve3D = $test/Path.curve
onready var pathFollow : PathFollow = $test/Path/PathFollow

func meshAlongCurve(meshIn : ArrayMesh, pathCurve : Path, destMesh : MeshInstance, startOffset : float = 0.0):
	"""
	Deforms the geometry of a given mesh along a curve
	"""
	var retArr : ArrayMesh = ArrayMesh.new()
	var meshAABB : AABB = meshIn.get_aabb()
	
	var curve : Curve3D = pathCurve.curve
	
	for surfIdx in meshIn.get_surface_count():
		var mdt : MeshDataTool = MeshDataTool.new()
		mdt.create_from_surface(meshIn, surfIdx)
		
		for vertIdx in mdt.get_vertex_count():
			var v : Vector3 = mdt.get_vertex(vertIdx)
			var vOffset : float = fmod(startOffset + (v.z - meshAABB.position.z), curve.get_baked_length())
			
#			#Tested the effect of using a PathFollow to sample the mesh (seemed slower)
#			var curveOffsetTransform : Transform = samplePathAtOffset(pathCurve, vOffset)
#			var curvePos : Vector3 = curveOffsetTransform.origin
#			var basisCorr : Basis = curveOffsetTransform.basis.orthonormalized()
#			var curveNorm : Vector3 = basisCorr.y
#			var curveX : Vector3 = basisCorr.x
			
			var curvePos : Vector3 = curve.interpolate_baked(vOffset, true)
			var curveNorm : Vector3 = curve.interpolate_baked_up_vector(vOffset, true)
			var curveZ : Vector3 = (curve.interpolate_baked(vOffset + EPSILON, true) - curvePos).normalized()
			var curveX : Vector3 = -curveZ.cross(curveNorm)
			
			mdt.set_vertex(vertIdx, curvePos + curveX * v.x + curveNorm * v.y)
		
		mdt.commit_to_surface(retArr)
	
	destMesh.mesh = retArr

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

func meshAroundCurve(meshIn : ArrayMesh, pathCurve : Path, startCurveOffset : float, startCircleOffset : float, circlePerimeter : float, destMesh : MeshInstance, usedAABB : AABB):
	"""
	Deforms the geometry of a given mesh along a curve
	"""
	var retArr : ArrayMesh = ArrayMesh.new()
	var circleRadius : float = circlePerimeter / TAU
	
	var curve : Curve3D = pathCurve.curve
	
	for surfIdx in meshIn.get_surface_count():
		var mdt : MeshDataTool = MeshDataTool.new()
		mdt.create_from_surface(meshIn, surfIdx)
		
		for vertIdx in mdt.get_vertex_count():
			var v : Vector3 = mdt.get_vertex(vertIdx)
			var vRel : Vector3 = v - usedAABB.position
			var vOffset : float = fmod(startCurveOffset + vRel.x, curve.get_baked_length())
			
			#Getting the axis of the circle at that point on the curve
			var curvePos : Vector3 = curve.interpolate_baked(vOffset, true)
			var curveNorm : Vector3 = curve.interpolate_baked_up_vector(vOffset, true)
			var curveZ : Vector3 = (curve.interpolate_baked(vOffset + EPSILON, true) - curvePos).normalized()
			var curveX : Vector3 = -curveZ.cross(curveNorm)
			
			#Getting the position and the axis on the circle
			var circleOffset : float = (startCircleOffset + vRel.z) / circleRadius
			var circlePos : Vector3 = curvePos + circleRadius * (cos(circleOffset) * curveX + sin(circleOffset) * curveNorm)
			var circleX : Vector3 = (circlePos - curvePos).normalized()
			var circleZ : Vector3 = circleX.cross(curveZ)
			
			var vNewPos : Vector3 = circlePos + v.y * circleX
			
			mdt.set_vertex(vertIdx, vNewPos)
		
		mdt.commit_to_surface(retArr)
	
	destMesh.mesh = retArr

func wrapGridmapLineAroundCurve(gridmap : GridMap, lineXCoordinate : int, startCurveOffset : float):
	"""
	Warps the element of a GridMap line (so all the occupied cells of a given x coordinates) around a curve
	"""
	var zCoord : int = 0
	
	#Creating surface tools containing the geometry of the different surfaces
	#Differents parts with the same material are combined together
	var lineItems : PoolIntArray = []
	var surfTools : Dictionary = {}
	while gridmap.get_cell_item(lineXCoordinate, 0, zCoord) != -1:
		lineItems.append(gridmap.get_cell_item(lineXCoordinate, 0, zCoord))
		
		var cellMesh : ArrayMesh = gridmap.mesh_library.get_item_mesh(lineItems[-1])
		
		for surfIdx in cellMesh.get_surface_count():
			var surfMat : Material = cellMesh.surface_get_material(surfIdx)
			if not surfMat in surfTools:
				surfTools[surfMat] = SurfaceTool.new()
			
			surfTools[surfMat].append_from(cellMesh, surfIdx, Utilities.getCellTransform(gridmap, Vector3(lineXCoordinate, 0, zCoord)))
		
		zCoord += 1
	
	#Creating the bounding box based on the cells (and not the geometry, since it might vary)
	var aabbOrigin : Vector3 = gridmap.map_to_world(lineXCoordinate, 0, 0) - (gridmap.cell_size / 2.0)
	var aabbSize : Vector3 = gridmap.cell_size * lineItems.size()
	var usedAABB : AABB = AABB(aabbOrigin, aabbSize)
	
	#Creating an ArrayMesh containing all the combined SurfaceTool
	var lineMesh : ArrayMesh = ArrayMesh.new()
	for mat in surfTools:
		var surfTool : SurfaceTool = surfTools[mat]
		lineMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surfTool.commit_to_arrays())
		lineMesh.surface_set_material(lineMesh.get_surface_count() - 1, mat)
	
	#Warping the geometry of the combined surfaces onto a circle around the curve
	var sectionMeshInst : MeshInstance = MeshInstance.new()
	$Sections.add_child(sectionMeshInst)
	meshAroundCurve(lineMesh, $test/Path, startCurveOffset, 0.0, lineItems.size() * gridmap.cell_size.z, sectionMeshInst, usedAABB)

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
	
	var start : float = OS.get_ticks_msec()
	
	for i in range(3):
		$Node.wrapGridmapLineAroundCurve($GridMap, 0, 7, i * $GridMap.cell_size.x * 9, $test/Path)

	var end : float = OS.get_ticks_msec()
	print(end - start)

func _process(delta):
	pathFollow.offset += delta * 5.0
