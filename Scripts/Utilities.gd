extends Node

func orthogonal_hren(value : int ):
	#Credits to user Tort from the Godot forums :)
	if value == 0:
		return(Vector3(0, 0, 0))
	elif value == 1:
		return(Vector3(0, 0, PI/2))
	elif value == 2:
		return(Vector3(0, 0, PI))
	elif value == 3:
		return(Vector3(0, 0, -PI/2))
	elif value == 4:
		return(Vector3(PI/2, 0, 0))
	elif value == 5:
		return(Vector3(PI, -PI/2, -PI/2))
	elif value == 6:
		return(Vector3(-PI/2, PI, 0))
	elif value == 7:
		return(Vector3(0, -PI/2, -PI/2))
	elif value == 8:
		return(Vector3(-PI, 0, 0))
	elif value == 9:
		return(Vector3(PI, 0, -PI/2))
	elif value == 10:
		return(Vector3(0, PI, 0))
	elif value == 11:
		return(Vector3(0, PI, -PI/2))
	elif value == 12:
		return(Vector3(-PI/2, 0, 0))
	elif value == 13:
		return(Vector3(0, -PI/2, PI/2))
	elif value == 14:
		return(Vector3(PI/2, 0, PI))
	elif value == 15:
		return(Vector3(0, PI/2, -PI/2))
	elif value == 16:
		return(Vector3(0, PI/2, 0))
	elif value == 17:
		return(Vector3(-PI/2, PI/2, 0))
	elif value == 18:
		return(Vector3(PI, PI/2, 0))
	elif value == 19:
		return(Vector3(PI/2, PI/2, 0))
	elif value == 20:
		return(Vector3(PI, -PI/2, 0))
	elif value == 21:
		return(Vector3(-PI/2, -PI/2, 0))
	elif value == 22:
		return(Vector3(0, -PI/2, 0))
	elif value == 23:
		return(Vector3(PI/2, -PI/2, 0))

func getCellTransform(gridmap : GridMap, gridCoords : Vector3) -> Transform:
	var ret : Transform = Transform.IDENTITY
	
	ret.origin = gridmap.map_to_world(gridCoords.x, gridCoords.y, gridCoords.z)
	ret.basis = Basis(orthogonal_hren(gridmap.get_cell_item_orientation(gridCoords.x, gridCoords.y, gridCoords.z)))
	
	return ret

func convertMeshToArrayMesh(inputMesh : Mesh) -> ArrayMesh:
	var outputMesh : ArrayMesh = ArrayMesh.new()
	
	for surfIdx in range(inputMesh.get_surface_count()):
		outputMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, inputMesh.surface_get_arrays(0))
		outputMesh.surface_set_material(surfIdx, inputMesh.surface_get_material(surfIdx))
	
	return outputMesh
	
func drawCurve(curve : Curve3D, curveDrawer : ImmediateGeometry):
	"""
	For debug purposes. Draws a Curve3d through an ImmediateGeometry node
	"""
	var curvePoints : PoolVector3Array = curve.get_baked_points()
	
	curveDrawer.clear()
	
	curveDrawer.begin(Mesh.PRIMITIVE_LINES)
	
	for i in range(curvePoints.size() - 1):
		curveDrawer.add_vertex(curvePoints[i])
		curveDrawer.add_vertex(curvePoints[i+1])
	
	curveDrawer.end()
