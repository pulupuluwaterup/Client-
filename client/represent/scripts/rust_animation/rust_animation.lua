Include ("represent/scripts/mathex.lua")
-- ===============================
-- **坐骑状态机模块**
-- ===============================
--全局表
MOVESTATES_RUST = {[1]=true, [2]=true, [3]=true, [4]=true, [22]=true }
ANIMATION_RUST = { [-1]=true, [0]=true}

tCharacterParamas = 
{
	moveSpeed = "Speed",
	moveDirection = "Direction",
	moveMode = "MoveMode",
	Run_F_PlayRate = "Run_F_PlayRate",
	YawOffset = "YawOffset",
	TurnOffset = "TurnOffset",
	StopMode = "StopMode",
	AccelerationRate = "AccelerationRate",
	LogicVelocity = "LogicVelocity",
	JumpCount = "JumpCount",
	JumpSwitch = "JumpSwitch",
	JumpMode = "JumpMode",
	MoveStateSwitch = "MoveStateSwitch", --跑步走路切换
	OnRide = "OnRide", --是否骑乘状态
	CurrentState = "CurrentState", --当前状态
	SprintStopMode = "SprintStopMode", --疾跑停止模式
	LastCurrentState = "LastCurrentState", --上次移动状态
	LastMoveState = "LastMoveState", --上次移动状态
	isRust = "isRust", --是否为Rust状态
	SprintTilt = "SprintTilt", --疾跑倾斜
}
tRideParams = 
{
	RunStartMode = "RunStartMode", --坐骑开始跑步模式
	RunF_Blend = "RunF_Blend", --坐骑跑步混合
	RunB_Blend = "RunB_Blend", --坐骑跑步混合
	DirectionOffset = "DirectionOffset", --坐骑方向偏移
	InputOffset = "InputOffset", --坐骑前进偏移
	StopMode = "StopMode", --坐骑前进后退
	MoveStateSwitch = "MoveStateSwitch", --坐骑跑步走路冲刺
	isRust = "isRust", --是否为Rust状态
}
RustInstances = {}
--变量
CharacterObj = nil
RideObj = nil --坐骑对象
deltaTime = 0.0 --时间差
function IsRustState(moveState)
    return MOVESTATES_RUST[moveState] == true
end
function NormalizedRotation(deg, maxDeg)
    if deg > maxDeg then deg = maxDeg end
    if deg < -maxDeg then deg = -maxDeg end
    return deg / maxDeg
end

function QuaternionToEuler(q)
    local qx, qy, qz, qw = q.x, q.y, q.z, q.w

    local sinr_cosp = 2 * (qw * qx + qy * qz)
    local cosr_cosp = 1 - 2 * (qx * qx + qy * qy)
    local roll = math.atan2(sinr_cosp, cosr_cosp)

    local sinp = 2 * (qw * qy - qz * qx)
    local pitch
    if math.abs(sinp) >= 1 then
        -- Pitch 超出范围 [-1, 1] 时，约为 ±90 度
        pitch = math.pi / 2 * (sinp < 0 and -1 or 1)
    else
        pitch = math.asin(sinp)
    end

    local siny_cosp = 2 * (qw * qz + qx * qy)
    local cosy_cosp = 1 - 2 * (qy * qy + qz * qz)
    local yaw = math.atan2(siny_cosp, cosy_cosp)

    -- 将弧度制转换为角度制并返回 Vector3 表
    return {x = math.deg(roll), y = math.deg(pitch), z = math.deg(yaw)}
end

function Lerp(a, b, t)
    return a + (b - a) * t
end
function Vector3_divide(v, s)
    return Vector3(v.x / s, v.y / s, v.z / s)
end
--计算两个四元数之间的夹角
function quaternion_angle(q1, q2)
    -- 计算四元数点积
	if q2.x < 0 then
		q2.x = -q2.x
		q2.y = -q2.y
		q2.z = -q2.z
		q2.w = -q2.w

	end
    local dot = q1.x * q2.x + q1.y * q2.y + q1.z * q2.z + q1.w * q2.w
    
    -- 确保点积在 [-1, 1] 范围内（避免浮点误差）
    dot = math.max(-1, math.min(1, dot))
	-- 计算夹角（弧度)
	radian =2 * math.acos(math.abs(dot))
	angle = math.deg(radian)
	 -- 通过四元数差计算方向
	 local delta_q = QuaternionConjugate(q1) * q2
	 local direction = delta_q.y * delta_q.w >= 0 and -1 or 1
	 -- 返回角度（弧度）和方向
	 return angle * direction
end
function UpdateCurrentTransform(obj,CharacterObj)
	local tCurrentT = 
	{--角色当前旋转四元数
		fPosX = 0.0,
		fPosY = 0.0,
		fPosZ = 0.0,
		fRotX = 0.0,
		fRotY = 0.0,
		fRotZ = 0.0,
		fRotW = 0.0
	}
	if obj.objectType == RUST_ANIMATION_OBJECT_TYPE.CHARACTER then
		tCurrentT.fPosX,tCurrentT.fPosY,tCurrentT.fPosZ,tCurrentT.fRotX,tCurrentT.fRotY,tCurrentT.fRotZ,tCurrentT.fRotW = CharacterObj.GetTransform()
	end
	return tCurrentT
end

function deltaTime()
	local detlaTime = GetTime() - GetTimeLast()
	deltaTime = detlaTime / 1000 --转换为秒
	return deltaTime
end
-- 四元数与向量旋转函数
local function rotateVectorByQuaternion(q, v)
    -- 提取四元数和向量分量
    local qw, qx, qy, qz = q.w, q.x, q.y, q.z
    local vx, vy, vz = v.x, v.y, v.z

    -- 四元数的共轭
    local qw_conj, qx_conj, qy_conj, qz_conj = qw, -qx, -qy, -qz

    -- 计算中间值 t = q * v
    local tw = -qx * vx - qy * vy - qz * vz
    local tx =  qw * vx + qy * vz - qz * vy
    local ty =  qw * vy + qz * vx - qx * vz
    local tz =  qw * vz + qx * vy - qy * vx

    -- 计算最终结果 v' = t * q^-1
    local rx = tx * qw_conj + tw * (-qx_conj) + ty * (-qz_conj) - tz * (-qy_conj)
    local ry = ty * qw_conj + tw * (-qy_conj) + tz * (-qx_conj) - tx * (-qz_conj)
    local rz = tz * qw_conj + tw * (-qz_conj) + tx * (-qy_conj) - ty * (-qx_conj)

    -- 返回旋转后的向量
    return rx, ry, rz
end
--计算四元数的方向向量
function CharacterParamsOnInit(dwRustID)
	 -- 注册初始参数
	 
	 RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.F, tCharacterParamas.moveSpeed, 0.0)
	 RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.F, tCharacterParamas.moveDirection, 0.0)
	 --RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.Run_F_PlayRate, 1)
	 RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.F,tCharacterParamas.YawOffset, 0.0)
	--RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.MoveMode, 0)
	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.StopMode, 0)
	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.F,tCharacterParamas.TurnOffset, 0.0)
	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.F,tCharacterParamas.AccelerationRate, 0.0)
	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.F,tCharacterParamas.LogicVelocity, 0.0)
	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.JumpCount, 0)
	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.JumpSwitch, 0)
	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.JumpMode, 0)
	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.MoveStateSwitch, 0) --跑步走路切换
	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.OnRide, 0) --是否骑乘状态
	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.CurrentState, 1) --当前状态
	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.SprintStopMode, 0) --疾跑停止模式
	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.isRust, 1) --是否为Rust状态


end
function RideParamsOnInit(dwRustID)
	 -- 注册初始参数
	 RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I, tRideParams.RunStartMode, 0) --坐骑开始跑步模式
	 RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I, tRideParams.RunF_Blend, 0) --坐骑跑步混合
	 RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I, tRideParams.RunB_Blend, 0) --坐骑跑步混合
	 RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.F, tRideParams.DirectionOffset, 0.0) --坐骑方向偏移
	 RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.F, tRideParams.InputOffset, 0.0) --坐骑前进偏移
	 RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I, tRideParams.StopMode, 0) --坐骑停止模式
	 RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I, tRideParams.MoveStateSwitch, 1) --坐骑跑步走路切换
	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tRideParams.isRust, 0) --是否为Rust状态
end
function UpdateCharacter(dwRustID,CharacterID)
	Instance = RustInstances[dwRustID]
	CharacterObj = GetLocalCharacter()
	
	if not CharacterObj then
		return nil
	end
	-------赋值-------
	frameData = CharacterObj.GetFrameData()
	local upid,downid =  CharacterObj.GetAnimationBodyState()
	local isLinking = CharacterObj.IsLinking()
	if frameData.bSheathFlag == false or frameData.bFightState == true or (upid ~= ANIMATION_UP_TYPE.UNKNOWN and upid ~= ANIMATION_UP_TYPE.NONE) or
		isLinking == true 
	then
		Instance.isRust = 0
		Instance.IsRustState = 0
	else
		Instance.isRust = 1
		Instance.IsRustState = 1
	end
	

	if not frameData.bOnRide then
		Instance.OnRide = 0 --非骑乘状态
		Instance.CurrentState = frameData.nMoveState
			--判断运动状态
		if Instance.CurrentState == 1 then
			Instance.MoveState = "STAND"
			
		end
		if Instance.CurrentState == 2 then
			Instance.MoveState = "WALK"
			Instance.MoveStateSwitch = 0 
		end
		if Instance.CurrentState == 3 and frameData.bSprintFlag == false then
			Instance.MoveState = "RUN"
			Instance.MoveStateSwitch = 1 
		end
		if Instance.CurrentState == 4 then
			Instance.MoveState = "JUMP"
		end
		if Instance.CurrentState == 3 and frameData.bSprintFlag == true and frameData.bParkourFlag == false and frameData.bSlideSprintFlag == false then
			Instance.MoveState = "SPRINT"
		end
		if Instance.CurrentState == 22 then
			Instance.MoveState = "SPRINT_STOP"
			Instance.MoveStateSwitch = 2
		end
		if  downid == 1 then
			RustAnimationBroadcastMessage(dwRustID,"TURN_NONE")
		end
		if downid == 2 then
			RustAnimationBroadcastMessage(dwRustID,"TURN_LEFT")
		end
		if downid == 3 then
			RustAnimationBroadcastMessage(dwRustID,"TURN_RIGHT")
		end


		if ((Instance.MoveState == "SPRINT") or IsRustState(frameData.nMoveState)) and Instance.IsRustState == 1 then
			Instance.isRust = 1
		else
			Instance.isRust = 0
		end
	
	
		--print("========================Character:更新角色参数========================")
		Instance.InputDirection.x, Instance.InputDirection.y, Instance.InputDirection.z, Instance.InputDirection.w = CharacterObj.GetLogicDirection()
		Instance.LogicFaceRotation.x,Instance.LogicFaceRotation.y,Instance.LogicFaceRotation.z,Instance.LogicFaceRotation.w = CharacterObj.GetLogicFaceRotation()
		Instance.ControlVector = Instance.LogicFaceRotation:Rotate(Instance.RotateVector)
		Instance.CurrentTransform = UpdateCurrentTransform(Instance,CharacterObj)
		Instance.LogicVelocity = frameData.nVelocityXY
		Instance.JumpCount = frameData.nJumpCount

		----------------------位移参数--------------------------
		Instance.Distance.x = Instance.CurrentTransform.fPosX - Instance.PreTransform.fPosX
		Instance.Distance.y = Instance.CurrentTransform.fPosY - Instance.PreTransform.fPosY
		Instance.Distance.z = Instance.CurrentTransform.fPosZ - Instance.PreTransform.fPosZ
		Instance.HorizonDistance = Instance.Distance:length_horizon()

		----------------------速度加速度--------------------------
		Instance.Velocity = Vector3_divide(Instance.Distance, deltaTime) * 1000 --转换为米每秒
		Instance.HorizonVelocity = Vector3(Instance.Velocity.x, 0, Instance.Velocity.z) --水平速度
		Instance.HorizonSpeed = Instance.HorizonDistance / deltaTime * 1000 --转换为米每秒
		Instance.moveSpeed = Instance.HorizonSpeed

		----------------------旋转参数--------------------------
		Instance.CurrentRotation = Quaternion(Instance.CurrentTransform.fRotX,Instance.CurrentTransform.fRotY,Instance.CurrentTransform.fRotZ,Instance.CurrentTransform.fRotW)
		Instance.moveDirection =  quaternion_angle(Instance.LogicFaceRotation,Instance.CurrentRotation)
		Instance.DirectionOffset = -quaternion_angle(Instance.PreRotation, Instance.CurrentRotation)


		--Instance.PlayerVector = Instance.CurrentRotation:Rotate(Instance.RotateVector) --角色前方向量
		--Instance.PlayerRotation = Instance.RotateVector:offsetAngle(Instance.PlayerVector) --角色前方向量相对于X轴的旋转角度
		Instance.VelocityRotation = Instance.RotateVector:offsetAngle(Instance.HorizonVelocity)
		Instance.ControlRotation = Instance.RotateVector:offsetAngle(Instance.ControlVector)

		Instance.InputVector = Instance.LogicDirection:Rotate(Instance.RotateVector) --控制器向量
		Instance.ControlInputRotation = quaternion_angle(Instance.InputDirection, Instance.LogicFaceRotation)
		


		----------------------计算方向--------------------------

		if Instance.ControlVector:length() > 0 then
			Instance.YawOffset = quaternion_angle(Instance.CurrentRotation, Instance.LogicFaceRotation)
			--Instance.ControlVector:offsetAngle(Instance.PlayerVector) --控制器向量和速度向量的夹角

		end
		if Instance.InputVector:length() > 0 then
			if Instance.ControlInputRotation >= -95 and Instance.ControlInputRotation <= 95 then
				Instance.MoveMentDirection = "Forward" --前进
			elseif Instance.ControlInputRotation > 95 or Instance.ControlInputRotation < -95 then
				Instance.MoveMentDirection = "BackWard" --后退
			end
		end
		if Instance.MoveMentDirection == "Forward" then
			Instance.StopMode = 0 --如果偏航角度在-95到95之间，则停止模式为0
		elseif Instance.MoveMentDirection == "BackWard" then
			Instance.StopMode = 1 --否则停止模式为1
		end

		Instance.SprintTilt = quaternion_angle(Instance.CurrentRotation, Instance.LogicFaceRotation) --疾跑倾斜角度

		Instance.TurnOffset = quaternion_angle(Instance.LogicFaceRotation, Instance.CurrentRotation)
		precurent = quaternion_angle(Instance.CurrentRotation, Instance.PreRotation)


		-----------------------开关--------------------------
		---StopMode开关：控制前后移动的停止表现
		--CurrentState开关：1-站立，2-行走，3-奔跑，4-跳跃/疾跑跳跃 22-疾跑停步

		if Instance.LastMoveState == "STAND" or Instance.LastMoveState == "WALK" then
			Instance.JumpMode = 0 --静止状态跳跃
		elseif Instance.LastMoveState == "RUN" then
			Instance.JumpMode = 1 --移动状态跳跃
		elseif Instance.LastMoveState == "SPRINT" then
			Instance.JumpMode = 2 --疾跑状态跳跃
		end
		
		--是否进入疾跑段

		if Instance.JumpCount == 1 and Instance.LastMoveState ~= "SPRINT" then
			Instance.JumpSwitch = 0 --一段跳落地

		elseif Instance.JumpCount == 2 then
			Instance.JumpSwitch = 1 --二段跳
		elseif Instance.LastMoveState == "SPRINT" and Instance.JumpCount == 1 then
			Instance.JumpSwitch = 2 --冲刺一段跳
		end
		
		if Instance.PreMoveState ~= Instance.MoveState then
			ChangeMoveState = true
			Instance.LastMoveState =Instance.PreMoveState
		end
		Instance.PreMoveState = Instance.MoveState
	
		
		
		Instance.PreTransform = Instance.CurrentTransform
		Instance.lastVelocity = Instance.Velocity --在最后将本帧的速度保存为上次速度
		Instance.lastHorizonSpeed = Instance.HorizonSpeed --在最后将本帧的水平速度保存为上次水平速度
		Instance.lastHorizonVelocity = Instance.HorizonVelocity --在最后将本帧的水平速度保存为上次水平速度
		Instance.lastHorizonAcceleration = Instance.HorizonAcceleration --在最后将本帧的水平加速度保存为上次水平加速度
		Instance.tPreTransform= Instance.CurrentTransform --在最后将本帧的Transform保存为上次Transform
		--Instance.PrePlayerRotation = Instance.PlayerRotation --在最后将本帧的角色前方向量相对于X轴的旋转角度保存为上次角色前方向量相对于X轴的旋转角度
		Instance.PreRotation.x, Instance.PreRotation.y, Instance.PreRotation.z, Instance.PreRotation.w = Instance.CurrentRotation.x, Instance.CurrentRotation.y, Instance.CurrentRotation.z, Instance.CurrentRotation.w
		Instance.PreLogicFaceRotation.x, Instance.PreLogicFaceRotation.y, Instance.PreLogicFaceRotation.z, Instance.PreLogicFaceRotation.w = Instance.LogicFaceRotation.x, Instance.LogicFaceRotation.y, Instance.LogicFaceRotation.z, Instance.LogicFaceRotation.w
		---------------------------------------------发送角色参数-----------------------------------------
	


	elseif frameData.bOnRide then
		
		Instance.OnRide = 1 --骑乘状态
		Instance.isRust = 0
	end
		RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I, tCharacterParamas.OnRide,Instance.OnRide) --是否骑乘状态
		RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.F,tCharacterParamas.moveSpeed,Instance.moveSpeed)
		RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.F,tCharacterParamas.moveDirection,Instance.moveDirection)
		RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.F,tCharacterParamas.YawOffset, Instance.YawOffset)
		RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.F,tCharacterParamas.TurnOffset, Instance.moveDirection)
		RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.F,tCharacterParamas.LogicVelocity, Instance.LogicVelocity)
		RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.JumpCount, Instance.JumpCount)
		RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.JumpMode, Instance.JumpMode)
		RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.JumpSwitch, Instance.JumpSwitch)
		RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.MoveStateSwitch, Instance.MoveStateSwitch) --跑步走路切换
		RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.StopMode, Instance.StopMode) --停止模式
		RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.CurrentState, Instance.CurrentState) --当前状态
		RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.SprintStopMode, Instance.SprintStopMode) --疾跑停止模式
		RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I,tCharacterParamas.isRust, Instance.isRust)
		RustAnimationBroadcastMessage(dwRustID, Instance.MoveMentDirection) --发送移动方向消息
		RustAnimationBroadcastMessage(dwRustID, Instance.MoveState) --发送移动状态消息
		testnum = 752151908
		RustAnimationSetExternalNodeID(dwRustID, testnum)

end
function UpdateRide(dwRustID,CharacterID)

	Instance = RustInstances[dwRustID]
	CharacterObj = GetLocalCharacter()
	if not CharacterObj then
		return nil
	end

	RideObj = CharacterObj.GetRide()  -- 获取坐骑对象
	
	if not RideObj then
		return nil
	end
	frameData = CharacterObj.GetFrameData()
	Instance.CurrentState = frameData.nMoveState
	if Instance.CurrentState == 1 then
		Instance.MoveState = "RIDE_STAND"
	end
	if Instance.CurrentState == 2 then
		Instance.MoveState = "RIDE_WALK"
		Instance.MoveStateSwitch = 0
	end
	if Instance.CurrentState == 3 and frameData.bSprintFlag == false then
		Instance.MoveState = "RIDE_RUN"
		Instance.MoveStateSwitch = 1
	end
	if Instance.CurrentState == 4 then
		Instance.MoveState = "RIDE_JUMP"
	end
	if frameData.bOnRide then
		Instance.OnRide = 1 --骑乘状态
		Instance.isRust = 0
	elseif  not frameData.bOnRide then
		Instance.OnRide = 0 --非骑乘状态
	end
	print(string.format("Instance.MoveState: %s", Instance.MoveState))
	Instance.InputDirection.x, Instance.InputDirection.y, Instance.InputDirection.z, Instance.InputDirection.w = CharacterObj.GetLogicDirection()

	Instance.LogicFaceRotation.x,Instance.LogicFaceRotation.y,Instance.LogicFaceRotation.z,Instance.LogicFaceRotation.w = CharacterObj.GetLogicFaceRotation()
	Instance.CurrentPosition.x, Instance.CurrentPosition.y, Instance.CurrentPosition.z = RideObj.GetCurrentShapePosition()
	Instance.CurrentRotation.x, Instance.CurrentRotation.y, Instance.CurrentRotation.z, Instance.CurrentRotation.w = RideObj.GetCurrentShapeRotation()

	Instance.FaceDirection = Instance.CurrentRotation:Rotate(Instance.RotateVector) 
	Instance.DirectionOffset = -quaternion_angle(Instance.PreRotation, Instance.CurrentRotation) 
	Instance.Distance = Instance.CurrentPosition - Instance.PrePosition

	Instance.Velocity = Vector3_divide(Instance.Distance, deltaTime) * 1000
	Instance.HorizonVelocity = Vector3(Instance.Velocity.x, 0, Instance.Velocity.z)
	Instance.HorizonDistance = Instance.Distance:length_horizon()
	InputLogicOffset = quaternion_angle(Instance.LogicFaceRotation, Instance.InputDirection) 
	PlayerLogicOffset = -quaternion_angle(Instance.CurrentRotation,Instance.LogicFaceRotation) --角色逻辑方向和输入方向的偏移角度
	PlayerLogicFaceOffset = -quaternion_angle(Instance.CurrentRotation,Instance.LogicFaceRotation) --角色逻辑方向和输入方向的偏移角度
	

	TEST = PlayerLogicOffset - InputLogicOffset --输入方向和角色逻辑方向的偏移角度
	if Instance.ControlVector:length() > 0 then
			Instance.YawOffset = quaternion_angle(Instance.CurrentRotation, Instance.LogicFaceRotation)
			--Instance.ControlVector:offsetAngle(Instance.PlayerVector) --控制器向量和速度向量的夹角

	end
	Instance.InputVector = Instance.LogicDirection:Rotate(Instance.RotateVector) --控制器向量
	Instance.ControlInputRotation = quaternion_angle(Instance.InputDirection, Instance.LogicFaceRotation)
	if Instance.InputVector:length() > 0 then
			if Instance.ControlInputRotation >= -95 and Instance.ControlInputRotation <= 95 then
				Instance.MoveMentDirection = "Forward" --前进
			elseif Instance.ControlInputRotation > 95 or Instance.ControlInputRotation < -95 then
				Instance.MoveMentDirection = "BackWard" --后退
			end
	end
	if Instance.MoveMentDirection == "Forward" then
		Instance.StopMode = 0 --如果偏航角度在-95到95之间，则停止模式为0
	elseif Instance.MoveMentDirection == "BackWard" then
		Instance.StopMode = 1 --否则停止模式为1
	end

	Instance.PrePosition.x, Instance.PrePosition.y, Instance.PrePosition.z = Instance.CurrentPosition.x, Instance.CurrentPosition.y, Instance.CurrentPosition.z
	Instance.PreRotation.x, Instance.PreRotation.y, Instance.PreRotation.z, Instance.PreRotation.w = Instance.CurrentRotation.x, Instance.CurrentRotation.y, Instance.CurrentRotation.z, Instance.CurrentRotation.w
	Instance.LastFaceDirection.x, Instance.LastFaceDirection.y, Instance.LastFaceDirection.z = Instance.FaceDirection.x, Instance.FaceDirection.y, Instance.FaceDirection.z
	Instance.LastLogicDirection.x, Instance.LastLogicDirection.y, Instance.LastLogicDirection.z = Instance.LogicDirection.x, Instance.LogicDirection.y, Instance.LogicDirection.z
	Instance.PreLogicFaceRotation.x, Instance.PreLogicFaceRotation.y, Instance.PreLogicFaceRotation.z, Instance.PreLogicFaceRotation.w = Instance.LogicFaceRotation.x, Instance.LogicFaceRotation.y, Instance.LogicFaceRotation.z, Instance.LogicFaceRotation.w
	Instance.PreControlInputRotation = Instance.ControlInputRotation
	--print("========================Ride:更新角色骑马参数========================")
	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I, tRideParams.isRust, Instance.isRust) --是否为Rust状态
	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I, tCharacterParamas.isRust,Instance.isRust) --坐骑跑步混合
	
	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.F, tRideParams.DirectionOffset, TEST) --坐骑方向偏移
	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.F, tRideParams.InputOffset, InputLogicOffset) --坐骑前进偏移

	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I, tRideParams.RunStartMode, Instance.TurnState) --坐骑开始跑步模式
	RustAnimationSetParameter(CharacterObj.GetRustAnimationID(), RUST_ANIMATION_PARAMETER_TYPE.I, tCharacterParamas.OnRide,Instance.OnRide)

	RustAnimationBroadcastMessage(dwRustID, Instance.MoveState) 
	RustAnimationBroadcastMessage(CharacterObj.GetRustAnimationID(), Instance.MoveState)

	RustAnimationBroadcastMessage(dwRustID, Instance.MoveMentDirection) --发送移动方向消息
	RustAnimationBroadcastMessage(CharacterObj.GetRustAnimationID(), Instance.MoveMentDirection)

	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I, tRideParams.StopMode, Instance.StopMode) --坐骑停止模式
	RustAnimationSetParameter(CharacterObj.GetRustAnimationID(), RUST_ANIMATION_PARAMETER_TYPE.I, tCharacterParamas.StopMode, Instance.StopMode)

	RustAnimationSetParameter(dwRustID, RUST_ANIMATION_PARAMETER_TYPE.I, tRideParams.MoveStateSwitch, Instance.MoveStateSwitch) --坐骑跑步走路切换



	--------------------------------输出角色的信息--------------------------------

end

function OnInit(eType, dwRustID, dwCharacterID)
	-- 初始化状态机实例
    RustInstances[dwRustID] = 
	{

        characterID = dwCharacterID,
		objectType = eType,  -- 记录对象类型
		CurrentState = 0, --当前状态
		DownID = 1,--下层动作ID
		isRust = 1,
		IsRustState = 0,
		MoveState = "STAND",
		PreMoveState = "STAND",
		LastMoveState = "STAND",

		--旋转参数--
		LogicFaceRotation = Quaternion(0.0, 0.0, 0.0, 0.0),
		PreLogicFaceRotation = Quaternion(0.0, 0.0, 0.0, 0.0), --上次逻辑方向四元数
		InputDirection =  Quaternion(0.0, 0.0, 0.0, 0.0), --角色逻辑方向向量
		
		ControlVector = Vector3(0.0, 0.0, 0.0), --角色面向LogicFaceDirection向量


		LogicDirection = Quaternion(0.0, 0.0, 0.0, 0.0), 
		LastLogicDirection = Quaternion(0.0, 0.0, 0.0, 0.0), --上次逻辑方向四元数
		InputVector = Vector3(0.0, 0.0, 0.0), --角色移动方向LogicDirection向量

		
		RotateVector = Vector3(0.0, 0.0, -1.0), --固定轴
		PlayerVector = Vector3(0.0, 0.0, 0.0), --角色前方向量CurrentTransform的前向向量
		

		PlayerRotation = 0.0,
		PrePlayerRotation = 0.0,
		ControlInputRotation = 0.0, 
		VelocityRotation = 0.0, 
		ControlRotation = 0.0, 
		PreControlInputRotation = 0.0,


		CurrentTransform = 
		{
			fPosX = 0.0,
			fPosY = 0.0,
			fPosZ = 0.0,
			fRotX = 0.0,
			fRotY = 0.0,
			fRotZ = 0.0,
			fRotW = 0.0
		},
		PreTransform = 
		{
			fPosX = 0.0,
			fPosY = 0.0,
			fPosZ = 0.0,
			fRotX = 0.0,
			fRotY = 0.0,
			fRotZ = 0.0,
			fRotW = 0.0
		},
		LogicVelocity = 0.0,
		Velocity = Vector3(0.0, 0.0, 0.0),
		HorizonVelocity = Vector3(0.0, 0.0, 0.0),
		HorizonSpeed = 0.0,
		
		MoveStateSwitch = 0, --跑步走路切换
		ControlStateSwitch = 0, --控制状态切换
		MoveMentDirection = "Forward", --移动方向
		OnRide = 0, --是否骑乘状态
		JumpCount = 0, --跳跃计数
		JumpSwitch = 0, --跳跃表现一二段跳
		JumpMode = 0, --跳跃模式--静止跳跃
		StopMode = 0, --停止模式
		SprintTilt = 0, --疾跑倾斜
		SprintStopMode = 0, --疾跑停止模式
		isFirstSprint = false, --是否第一次疾跑

		Distance = Vector3(0.0, 0.0, 0.0), --位移向量
		HorizonDistance = 0.0, --水平位移
		

		-----角色传参---
		moveSpeed = 0.0, --移动速度
		moveDirection = 0.0, --移动面向
		
		YawOffset = 0.0, --偏航角度
		TurnOffset = 0.0, --转向角度


		------马匹对象-------
		CurrentPosition = Vector3(0.0, 0.0, 0.0), --坐骑当前位置信息
		CurrentRotation = Quaternion(0.0, 0.0, 0.0, 0.0), --坐骑当前旋转四元数
		PreCurrentRotation = Quaternion(0.0, 0.0, 0.0, 0.0),
		HorizonDistance = 0.0, --坐骑水平位移
		PrePosition = Vector3(0.0, 0.0, 0.0), --坐骑上次位置信息
		PreRotation = Quaternion(0.0, 0.0, 0.0, 0.0), --坐骑上次旋转四元数
		FaceDirection = Vector3(0.0, 0.0, 0.0), --坐骑面向方向
		LastFaceDirection = Vector3(0.0, 0.0, 0.0), --坐骑上次面向方向
		ControlRideRotation = 0.0, --控制器向量和坐骑前方向量的夹角
		DirectionOffset = 0.0, --坐骑方向偏移
		TurnState = 1, --转向状态

    }
	Instance = RustInstances[dwRustID]
	CharacterObj = GetLocalCharacter()
	frameData = CharacterObj.GetFrameData()

	if not CharacterObj then
		return nil
	end

	if  RustInstances[dwRustID].objectType == RUST_ANIMATION_OBJECT_TYPE.CHARACTER then
		CharacterParamsOnInit(Instance,dwRustID)
	elseif RustInstances[dwRustID].objectType == RUST_ANIMATION_OBJECT_TYPE.RIDE then
		if frameData.bOnRide then
			RideObj = CharacterObj.GetRide()  
		end
		
		if not RideObj then
			return nil
		end
		RideParamsOnInit(Instance,dwRustID)
	end

end

function OnUnInit(eType, dwRustID, dwCharacterID)
	if RustInstances[dwRustID] then

		RustInstances[dwRustID] = nil
    end
end

function OnUpdate(eType, dwRustID, dwCharacterID)
	deltaTime = GetTime() - GetTimeLast()
	Instance = RustInstances[dwRustID]
	CharacterObj = GetLocalCharacter()
	frameData = CharacterObj.GetFrameData()

	if not Instance then 
		return nil
	end

	if Instance.objectType == RUST_ANIMATION_OBJECT_TYPE.CHARACTER then	
		UpdateCharacter(dwRustID,CharacterID)
	end
	if Instance.objectType == RUST_ANIMATION_OBJECT_TYPE.RIDE then

		if frameData.bOnRide then
			UpdateRide(dwRustID,CharacterID)
		end
		
	end
end

function OnPositionChanged(eType, dwRustID, dwCharacterID, fPrePositionX, fPrePositionY, fPrePositionZ)

end

function OnDirectionChanged(eType, dwRustID, dwCharacterID, fPreRotationX, fPreRotationY, fPreRotationZ, fPreRotationW)--控制器旋转的时候

	local instance = RustInstances[dwRustID]
    if not instance then 
		return 
	end

end