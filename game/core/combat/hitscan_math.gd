class_name HitscanMath
extends RefCounted
## Pure ray tests against player hit volumes (vertical capsule body + head sphere).


## Distance along the (normalized) ray to the sphere, or -1.
static func ray_sphere(origin: Vector3, dir: Vector3, center: Vector3, radius: float) -> float:
	var oc := origin - center
	var b := oc.dot(dir)
	var c := oc.dot(oc) - radius * radius
	var disc := b * b - c
	if disc < 0.0:
		return -1.0
	var s := sqrt(disc)
	var t := -b - s
	if t < 0.0:
		t = -b + s
	return t if t >= 0.0 else -1.0


## Vertical capsule from base (feet) with total height and radius. Distance or -1.
static func ray_capsule(origin: Vector3, dir: Vector3, base: Vector3, height: float, radius: float) -> float:
	var a := base + Vector3(0, radius, 0)
	var b := base + Vector3(0, maxf(radius, height - radius), 0)
	var best := -1.0
	# Infinite cylinder around the Y axis through a/b, clipped to the segment.
	var ox := origin.x - a.x
	var oz := origin.z - a.z
	var qa := dir.x * dir.x + dir.z * dir.z
	if qa > 1e-8:
		var qb := 2.0 * (ox * dir.x + oz * dir.z)
		var qc := ox * ox + oz * oz - radius * radius
		var disc := qb * qb - 4.0 * qa * qc
		if disc >= 0.0:
			var s := sqrt(disc)
			for t: float in [(-qb - s) / (2.0 * qa), (-qb + s) / (2.0 * qa)]:
				if t >= 0.0:
					var y := origin.y + dir.y * t
					if y >= a.y and y <= b.y:
						best = t if best < 0.0 else minf(best, t)
						break
	for cap: Vector3 in [a, b]:
		var t := ray_sphere(origin, dir, cap, radius)
		if t >= 0.0:
			best = t if best < 0.0 else minf(best, t)
	return best


## Returns {hit: bool, distance: float, headshot: bool} against one player.
static func test_player(origin: Vector3, dir: Vector3, feet: Vector3, body_height: float, body_radius: float, head_center_height: float, head_radius: float) -> Dictionary:
	var head := ray_sphere(origin, dir, feet + Vector3(0, head_center_height, 0), head_radius)
	var body := ray_capsule(origin, dir, feet, body_height, body_radius)
	if head >= 0.0 and (body < 0.0 or head <= body + 0.05):
		return {"hit": true, "distance": head, "headshot": true}
	if body >= 0.0:
		return {"hit": true, "distance": body, "headshot": false}
	return {"hit": false, "distance": -1.0, "headshot": false}


## Deterministic spread: rotates `dir` inside a cone using two random numbers in [0, 1).
static func apply_spread(dir: Vector3, degrees: float, u: float, v: float) -> Vector3:
	if degrees <= 0.0:
		return dir
	var angle := deg_to_rad(degrees) * sqrt(u)
	var theta := TAU * v
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT).normalized()
	var up := side.cross(dir).normalized()
	var offset := (side * cos(theta) + up * sin(theta)) * tan(angle)
	return (dir + offset).normalized()
