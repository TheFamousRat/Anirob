tool
extends Spatial

export var generateNewCurve : bool setget genNewCurve
export var pointsCount : int = 5
export var curveLen : float = 2.0
export var noiseScale : float = 1.0
export var effectScale : float = 1.0
export var noiseParams : OpenSimplexNoise = OpenSimplexNoise.new()

const EPSILON : float = 1e-2

func genNewCurve(v : bool = false):
	var curve : Curve3D = $Path.curve
	
	var segmentLength : float = curveLen / pointsCount
	
	curve.clear_points()
	
	var thetaNoiseGen : OpenSimplexNoise = noiseParams
	thetaNoiseGen.seed = OS.get_ticks_usec()
	var phiNoiseGen : OpenSimplexNoise = thetaNoiseGen.duplicate()
	phiNoiseGen.seed = thetaNoiseGen.seed + 1
	
	#Creating the points of the curve
	var prevThetaNoise : float = 0.0
	var prevPhiNoise : float = 0.0
	for i in range(0, pointsCount+1):
		var pIdx : int = i
		
		var distBase : Vector3 = (i) * segmentLength * Vector3(1,0,0)
		var theta : float = noiseScale * thetaNoiseGen.get_noise_3dv(distBase) + PI/2.0
		var phi : float = noiseScale * phiNoiseGen.get_noise_3dv(distBase)
		
		var newPoint = effectScale * Vector3(cos(phi) * sin(theta), sin(phi) * sin(theta), cos(theta))
		curve.add_point(distBase + newPoint)
	
	#Offsetting the coordinates so the first point is at 0
	var initialPos : Vector3 = Vector3(50,0,0)#curve.get_point_position(0)
	for i in range(0, curve.get_point_count()):
		curve.set_point_position(i, curve.get_point_position(i) - initialPos)
	
	if false:
		simplifyCurve(curve)
	
func simplifyCurve(curve : Curve3D):
	var idxToRemove : PoolIntArray = []
	var lastStablePoint : int = -1
	var stablePointPos : Vector3 = Vector3()
	var dirAtStablePoint : Vector3 = Vector3()
	var setNewStablePoint : bool = true
	var MARGIN : float = 0.1
	
	for i in range(1, curve.get_point_count() - 1):
		var pointOffset : float = curve.get_closest_offset(curve.get_point_position(i))
		var pointDir : Vector3 = (curve.interpolate_baked(pointOffset + EPSILON) - curve.get_point_position(i)).normalized()
		
		setNewStablePoint = true
		if lastStablePoint != -1:
			var temp = abs(dirAtStablePoint.dot(pointDir))
			print(temp)
			if temp >= 0.99999:
				setNewStablePoint = false
				idxToRemove.append(i)
				
		if setNewStablePoint:
			lastStablePoint = i
			stablePointPos = curve.get_point_position(lastStablePoint)
			var stablePointOffset : float = curve.get_closest_offset(stablePointPos)
			dirAtStablePoint = (curve.interpolate_baked(stablePointOffset + EPSILON) - stablePointPos).normalized()
	
	for i in range(idxToRemove.size() - 1, -1, -1):
		curve.remove_point(idxToRemove[i])
