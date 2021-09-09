#include "Curver.hpp"

using namespace godot;

void Curver::_register_methods()
{
	register_method("_init", &Curver::_init);
    register_method("_enter_tree", &Curver::_enter_tree);
    register_method("wrapGridmapLineAroundCurve", &Curver::wrapGridmapLineAroundCurve);
}

Curver::Curver() {

}

Curver::~Curver() {

}

void Curver::_init() {
    
}

void Curver::_enter_tree() {

}

Vector3 orthogonal_hren(int value) {
    //Credits to user Tort from the Godot forums :)
    switch (value)
    {
        case 0:
            return(Vector3(0, 0, 0));
            break;
        case 1:
            return(Vector3(0, 0, M_PI_2));
            break;
        case 2:
            return(Vector3(0, 0, M_PI));
            break;
        case 3:
            return(Vector3(0, 0, -M_PI_2));
            break;
        case 4:
            return(Vector3(M_PI_2, 0, 0));
            break;
        case 5:
            return(Vector3(M_PI, -M_PI_2, -M_PI_2));
            break;
        case 6:
            return(Vector3(-M_PI_2, M_PI, 0));
            break;
        case 7:
            return(Vector3(0, -M_PI_2, -M_PI_2));
            break;
        case 8:
            return(Vector3(-M_PI, 0, 0));
            break;
        case 9:
            return(Vector3(M_PI, 0, -M_PI_2));
            break;
        case 10:
            return(Vector3(0, M_PI, 0));
            break;
        case 11:
            return(Vector3(0, M_PI, -M_PI_2));
            break;
        case 12:
            return(Vector3(-M_PI_2, 0, 0));
            break;
        case 13:
            return(Vector3(0, -M_PI_2, M_PI_2));
            break;
        case 14:
            return(Vector3(M_PI_2, 0, M_PI));
            break;
        case 15:
            return(Vector3(0, M_PI_2, -M_PI_2));
            break;
        case 16:
            return(Vector3(0, M_PI_2, 0));
            break;
        case 17:
            return(Vector3(-M_PI_2, M_PI_2, 0));
            break;
        case 18:
            return(Vector3(M_PI, M_PI_2, 0));
            break;
        case 19:
            return(Vector3(M_PI_2, M_PI_2, 0));
            break;
        case 20:
            return(Vector3(M_PI, -M_PI_2, 0));
            break;
        case 21:
            return(Vector3(-M_PI_2, -M_PI_2, 0));
            break;
        case 22:
            return(Vector3(0, -M_PI_2, 0));
            break;
        case 23:
            return(Vector3(M_PI_2, -M_PI_2, 0));
            break;
    }
}

Transform Curver::getCellTransform(GridMap* gridmap, Vector3 gridCoords) {
    Transform ret;
	
	ret.origin = gridmap->map_to_world(gridCoords.x, gridCoords.y, gridCoords.z);
	ret.basis = Basis(orthogonal_hren(gridmap->get_cell_item_orientation(gridCoords.x, gridCoords.y, gridCoords.z)));
	
	return ret;
}

void Curver::meshAroundCurve(ArrayMesh* meshIn, Path* pathCurve, float startCurveOffset, float startCircleOffset, float circlePerimeter, MeshInstance* destMesh, AABB usedAABB) {
	godot::Ref<godot::ArrayMesh> curvedMesh;
    curvedMesh.instance();
	float circleRadius = circlePerimeter / Math_TAU;
	
	Curve3D* curve = pathCurve->get_curve().ptr();
	
	for (int surfIdx(0) ; surfIdx < meshIn->get_surface_count() ; surfIdx++) {
        MeshDataTool* mdt = MeshDataTool::_new();
		mdt->create_from_surface(meshIn, surfIdx);

		for (int vertIdx(0) ; vertIdx < mdt->get_vertex_count() ; vertIdx++) {
            Vector3 v = mdt->get_vertex(vertIdx);
			Vector3 vRel = v - usedAABB.position;
			float vOffset = fmod(startCurveOffset + vRel.x, curve->get_baked_length());
			
			//Getting the axis of the circle at that point on the curve
			Vector3 curvePos = curve->interpolate_baked(vOffset, true);
			Vector3 curveNorm = curve->interpolate_baked_up_vector(vOffset, true);
			Vector3 curveZ = (curve->interpolate_baked(vOffset + EPSILON, true) - curvePos).normalized();
			Vector3 curveX = -curveZ.cross(curveNorm);
			
			//Getting the position and the axis on the circle
			float circleOffset = (startCircleOffset + vRel.z) / circleRadius;
			Vector3 circlePos = curvePos + circleRadius * (cos(circleOffset) * curveX + sin(circleOffset) * curveNorm);
			Vector3 circleX = (circlePos - curvePos).normalized();
			Vector3 circleZ = circleX.cross(curveZ);
			
			Vector3 vNewPos = circlePos + v.y * circleX;
			
			mdt->set_vertex(vertIdx, vNewPos);
        }
		
		mdt->commit_to_surface(curvedMesh);
    }
		
	destMesh->set_mesh(curvedMesh);
}

void Curver::wrapGridmapLineAroundCurve(GridMap* gridmap, int lineXBegin, int lineXEnd, float startCurveOffset, Path* curvingPath) {
	//Creating surface tools containing the geometry of the different surfaces
	//Differents parts with the same material are combined together
    std::unordered_map<Material*, SurfaceTool*> surfTools;

    //gridmap->get_mesh_library().ptr()->get_item_mesh();
    int maxZ = 0;

    for (int lineXCoordinate(lineXBegin) ; lineXCoordinate <= lineXEnd ; lineXCoordinate++) {
        int zCoord = 0;
        int cellItem = gridmap->get_cell_item(lineXCoordinate, 0, zCoord);

        while (cellItem != -1) {
            maxZ = std::max(maxZ, zCoord);

            Mesh* cellMesh = gridmap->get_mesh_library().ptr()->get_item_mesh(cellItem).ptr();
            
            for (int surfIdx = 0 ; surfIdx < cellMesh->get_surface_count() ; surfIdx++) {
                Material* surfMat  = cellMesh->surface_get_material(surfIdx).ptr();

                if (surfTools.find(surfMat) == surfTools.end()) {
                    surfTools.insert({surfMat, SurfaceTool::_new()});
                }
                
                surfTools[surfMat]->append_from(cellMesh, surfIdx, getCellTransform(gridmap, Vector3(lineXCoordinate, 0, zCoord)));
            } 

            zCoord++;
            cellItem = gridmap->get_cell_item(lineXCoordinate, 0, zCoord);
        }
    }
	
	//Creating the bounding box based on the cells (and not the geometry, since it might vary)
	Vector3 aabbOrigin = gridmap->map_to_world(lineXBegin, 0, 0) - (gridmap->get_cell_size() / 2.0);
	Vector3 aabbSize = gridmap->get_cell_size() * maxZ;
	AABB usedAABB = AABB(aabbOrigin, aabbSize);
	
	//Creating an ArrayMesh containing all the combined SurfaceTool
	ArrayMesh* lineMesh = ArrayMesh::_new();

    for (auto it : surfTools) {
        Material* mat = it.first;
        SurfaceTool* surfTool = it.second;
		lineMesh->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES, surfTool->commit_to_arrays());
		lineMesh->surface_set_material(lineMesh->get_surface_count() - 1, mat);
    }
	
	//Warping the geometry of the combined surfaces onto a circle around the curve
	MeshInstance* sectionMeshInst  = MeshInstance::_new();
    get_parent()->get_node("Sections")->add_child(sectionMeshInst);
    sectionMeshInst->set_translation(Vector3(10,0,0));
    sectionMeshInst->set_mesh(lineMesh);
	meshAroundCurve(lineMesh, curvingPath, startCurveOffset, 0.0, usedAABB.size.z, sectionMeshInst, usedAABB);
}