
function Clamp(v, m, M)
	v = (v < m and m) or v
	v = (v > M and M) or v
	return v
end

local Meta_Vector3 = { ISVECTOR3 = true }
Meta_Vector3.__index = Meta_Vector3 

function Vector3(x, y, z)
	x = x or 0
	y = y or 0
	z = z or 0
	local vec = { x = x, y = y, z = z }
	function vec:ToArgs() return self.x, self.y, self.z end
	setmetatable(vec, Meta_Vector3)
	return vec
end

function Vector3Copy(other)
	local vec = Vector3(other.x, other.y, other.z)
	return vec
end

function Meta_Vector3.__add(lhs, rhs)
	return Vector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
end

function Meta_Vector3.__sub(lhs, rhs)
	return Vector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
end

function Meta_Vector3.__mul(lhs, s)
	return Vector3(lhs.x * s, lhs.y * s, lhs.z * s)
end


function Meta_Vector3:offsetAngle(rhs)
	if rhs:length() == 0 then
		return 0.0
	end
	local angle = self:angle(rhs)
	angle =	math.deg(angle)
	local cross = self:cross(rhs)
	if cross.y > 0 then
		return angle
	else
		return -angle
	end
end

function Meta_Vector3:cross(rhs)
	return Vector3(self.y * rhs.z - self.z * rhs.y, self.z * rhs.x - self.x * rhs.z, self.x * rhs.y - self.y * rhs.x)
end

function Meta_Vector3:lensqr()
	return self.x * self.x + self.y * self.y + self.z * self.z
end

function Meta_Vector3:length()
	return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end

function Meta_Vector3:length_horizon()
	return math.sqrt(self.x * self.x + self.z * self.z)
end

function Meta_Vector3:length_vertical()
	return math.abs(self.y)
end

function Meta_Vector3:distance(point)
	return math.sqrt((self.x - point.x) ^ 2 + (self.y - point.y) ^ 2 + (self.z - point.z) ^ 2)	
end

function Meta_Vector3:normalize()
	local epsilon = 0.00001
	local l = self:lensqr()
	if (l < epsilon) then
		self.x = 0
		self.y = 0
		self.z = 1
	else
		local lv = 1.0 / math.sqrt(l)
		self.x = self.x * lv
		self.y = self.y * lv
		self.z = self.z * lv
	end	
	return self
end

function Meta_Vector3:dot(rhs)
	return self.x * rhs.x + self.y * rhs.y + self.z * rhs.z
end

function Meta_Vector3:angle(rhs) 
	local _cos = self:dot(rhs) / (self:length() * rhs:length())
	_cos = Clamp(_cos, -1, 1)
	return math.acos(_cos)
end

local Meta_Quaternion = { ISQUAT = true }
Meta_Quaternion.__index = Meta_Quaternion 

function Quaternion(x, y, z, w)
	x = x or 0
	y = y or 0
	z = z or 0
	w = w or 1
	local quat = { x = x, y = y, z = z, w = w}
	function quat:ToArgs() return self.x, self.y, self.z, self.w end
	setmetatable(quat, Meta_Quaternion)
	return quat
end

function QuaternionByDir(dir)
	local rdir = Vector3Copy(dir)
	rdir:normalize()
	local dotv = rdir:dot(Vector3(0, 1, 0))
	if (math.abs(dotv - 1) < 0.01) then
		return Quaternion(0, 0, 0, 1)
	elseif (math.abs(dotv + 1) < 0.01) then
		return Quaternion(-0.7071, 0, 0, 0.7071)
	else
		local vxz = Vector3(rdir.x, 0, rdir.z)
		vxz:normalize()
		local axz = Vector3(0, 0, 1):angle(vxz)
		local sinxz = math.sin(axz * 0.5)
		local cosxz = math.cos(axz * 0.5)
		local dxz = Vector3(0, 0, 1):cross(vxz):normalize() * sinxz
		local qxz = Quaternion(dxz.x, dxz.y, dxz.z, cosxz)
				
		local ay = vxz:angle(rdir)
		local siny = math.sin(ay * 0.5)
		local cosy = math.cos(ay * 0.5)
		local dy = vxz:cross(rdir):normalize() * siny
		--local dy = rdir:cross(vxz):normalize() * siny
		local qy = Quaternion(dy.x, dy.y, dy.z, cosy)
				
		return qy * qxz
	end
end

function QuaternionConjugate(q)
	return Quaternion(-q.x, -q.y, -q.z, q.w)
end

function QuaternionByAngle(alpha, theta)
	local vxz = Vector3(0, 1, 0) * math.sin(alpha * 0.5)
	local qxz = Quaternion(vxz.x, vxz.y, vxz.z, math.cos(alpha * 0.5))
	local vy = qxz:Rotate(Vector3(1, 0, 0)) * math.sin(theta * 0.5)
	local qy = Quaternion(vy.x, vy.y, vy.z, math.cos(theta * 0.5))
	return qy * qxz
end

function QuaternionByAxisAngle(axis, radian)
	local sinr = math.sin(radian * 0.5)
	local cosr = math.cos(radian * 0.5)
	return Quaternion(sinr * axis.x, sinr * axis.y, sinr * axis.z, cosr)
end

function Meta_Quaternion.__mul(lhs, rhs)
	local x = lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y
	local y = lhs.w * rhs.y + lhs.y * rhs.w + lhs.z * rhs.x - lhs.x * rhs.z
	local z = lhs.w * rhs.z + lhs.z * rhs.w + lhs.x * rhs.y - lhs.y * rhs.x
	local w = lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z
	return Quaternion(x, y, z, w)
end

function Meta_Quaternion:Rotate(rhs)
	local   qvec = Vector3(self.x, self.y, self.z)
	local	uv   = qvec:cross(rhs)
	local   uuv  = qvec:cross(uv)
	uv  = uv * 2 * self.w
	uuv = uuv * 2
	return rhs + uv + uuv
end

local hasSeed = false
function Random(a, b)
	if (not hasSeed) then
		math.randomseed(os.time())
		hasSeed = true
	end
	local r = math.random(1, 10000)
	local t = (r - 1) / 10000
	return a * (1 - t) + t * b
end

function GetRotateVectorAroundAxisWithOffset(tAnchor,tPos,tAxis,fAngel)
	local tNewPos = {
		x = tPos.x - tAnchor.x,
		y = tPos.y - tAnchor.y,
		z = tPos.z - tAnchor.z,
	}

	local vx,vy,vz = GetRotateVectorAroundAxis(tNewPos,tAxis,fAngel)
	local tFinPos = {
		x = vx + tAnchor.x,
		y = vy + tAnchor.y,
		z = vz + tAnchor.z,
	}
	return tFinPos.x,tFinPos.y,tFinPos.z
end

function GetLineByTwoPoints(x1,y1,x2,y2)
	local a = y2-y1
	local b = x1-x2
	local c = x2*y1-x1*y2
	return a,b,c
end

function GetPoint2LineDistance(x,y,a,b,c)
	return (math.abs(a*x+b*y+c)/math.sqrt(a^2+b^2))
end

function Change(a,b)
	return b,a
end

function CheckPointBetweenTwoPoints(x,y,x1,y1,x2,y2,MinDistance)
	MinDistance = MinDistance or 0
	if (x1 >= x2) then
		x1,x2 = Change(x1,x2)
	end

	if ((x2 - x1) < MinDistance) then
		x2 = x2 + MinDistance/2
		x1 = x1 - MinDistance/2
	end

	if (y1 >= y2) then
		y1,y2 = Change(y1,y2)
	end

	if ((y2 - y1) < MinDistance) then
		y2 = y2 + MinDistance/2
		y1 = y1 - MinDistance/2
	end

	if ((x >= x1) and (x <= x2) and (y >= y1) and (y <= y2)) then
		return true
	else
		return false
	end
end

function EasyEncrypt(t)
	local nCode = 0
	for i = 1,#t do
		if(type(t[i]) == "number") or (type(t[i]) == "string") then
			nCode = nCode + tonumber(string.byte(t[i]))
		end
	end 
	nCode = math.abs(nCode - 2006)
	nCode = math.floor(math.sqrt(nCode)) + 516
	return nCode
end
function QuaternionToEuler(q)
	local roll = math.atan(2 * (q.w * q.z + q.x * q.y), 1 - 2 * (q.x * q.x + q.z * q.z))
	local pitch = math.asin(2 * (q.w * q.x - q.z * q.y))
	local yaw = math.atan(2 * (q.w * q.y + q.x * q.z), 1 - 2 * (q.y * q.y + q.x * q.x))

	return pitch, yaw, roll
end