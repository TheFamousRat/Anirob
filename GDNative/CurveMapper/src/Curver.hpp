#ifndef CURVER_HPP
#define CURVER_HPP

#include <iostream>
#include <math.h>
#include <unordered_map>

#include <Godot.hpp>
#include <Node.hpp>
#include <GridMap.hpp>
#include <MeshLibrary.hpp>
#include <Material.hpp>
#include <ArrayMesh.hpp>
#include <SurfaceTool.hpp>
#include <MeshInstance.hpp>
#include <Path.hpp>
#include <MeshDataTool.hpp>
#include <Curve3D.hpp>

#define EPSILON 1e-2

using namespace godot;

class Curver : public Node
{
    GODOT_CLASS(Curver, Node);

    private:
        /* data */
    public:
        Curver(/* args */);
        ~Curver();

        void _init();
        void _enter_tree();

        Transform getCellTransform(GridMap* gridmap, Vector3 gridCoords);

        /*
	    *Warps the element of a GridMap line (so all the occupied cells of a given x coordinates) around a curve
	    */
        void wrapGridmapLineAroundCurve(GridMap* gridmap, int lineXBegin, int lineXEnd, float startCurveOffset, Path* curvingPath);

        /*
	    *Deforms the geometry of a given mesh along a curve
	    */
       void meshAroundCurve(ArrayMesh* meshIn, Path* pathCurve, float startCurveOffset, float startCircleOffset, float circlePerimeter, MeshInstance* destMesh, AABB usedAABB);

        static void _register_methods();

};



#endif
