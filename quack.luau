--!optimize 2
--!strict

-- Quack
-- A lightweight-ish color quantization library for luau
-- Based on image-quantization and RgbQuant
-- @Kalrnlo
-- 17/02/2024

--[[
local Image1 = Quant.ExtractData(EditableImage)
local Image2 = Quack.ExtractData(EditableImage)
local Image3 = Quack.ExtractData(EditableImage)
Quack.ExtractDataFor(EditableImage1, EditableImage2, EditableImage3)

local Palette = Quack.PalletizeAsync(table.pack(Image1, Image2, Image3), {
	DitheringMethod = "FloydSteinberg",
	DistanceFormula = "Manhattan",
	Method = "GlobalPopulation",
	Colors = 256
}):Await()

local Palette = Quack.Palletize(Image, {
	DitheringMethod = "FloydSteinberg",
	DistanceFormula = "Manhattan",
	Method = "GlobalPopulation",
	Colors = 256
})

Quack.Dither("FloydSteinberg", Image)
--]]

local Future = require(script.Parent.Future)

type DitheringMethod = "FloydSteinberg" | "FalseFloydSteinberg" | "Stucki" | "Atkinson" |
	"Jarvis" | "Burkes" | "Sierra" | "TwoSierra" | "SierraLite" | 
	"ErrorDiffusionRiemersma" | "NearestColor"

type DistanceFormula = "Manhattan" | "Euclidean" | "ManhattanBT709" | "CMetric" |
	"ManhattanNommyde" | "EuclideanBT709" | "PNGQuant"

type Method = "GlobalPopulation" | "SubRegionPopulation"

type ReturnAs = "buffer" | "table" | "Color3"

type CalcuatorFunction = (
    self: DistanceCalcuator,
    R1: number,
    G1: number,
    B1: number,
    A1: number,
    R2: number,
    G2: number,
    B2: number,
    A2: number
) -> number

type DistanceFormulaDefaults = {
    KR: number,
    KG: number,
    KB: number,
    KA: number,   
}

type PalettePrototype = {

    -- tostring(Palette) returns the first color in the palette as a hex color string
    __tostring: (self: PalettePrototype) -> string,
	__len: (self: PalettePrototype) -> number,
}

type Palette = typeof(setmetatable({} :: {

}, {} :: PalettePrototype))

type HilbertCurve = {
	Visit: (self: HilbertCurve, Direction: number) -> (),
	Walk: (self: HilbertCurve, Direction: number) -> (),
	Callback: (X: number, Y: number) -> (),
	Height: number,
	Width: number,
	Level: number,
	X: number,
	Y: number,
}

type DistanceCalcuator = {
	CalcuateNormalized: CalcuatorFunction,
    Defualts: DistanceFormulaDefaults,
    CalculateRaw: CalcuatorFunction,
    WhitepointR: number,
    WhitepointG: number,
    WhitepointB: number,
    WhitepointA: number,
}

type ImageData = {
	Pixels: buffer,
	Height: number,
	Width: number,
}

-- sRGB (based on ITU-R Recommendation BT.709)
-- http://en.wikipedia.org/wiki/SRGB
local BT709 = {
	Y = {
		RED = 0.64,
		GREEN = 0.3,
		BLUE = 0.15,
		WHITE = 0.3127,
	},
	x = {
		RED = 0.64,
		GREEN = 0.3,
		BLUE = 0.15,
		WHITE = 0.3127,
	},
	y = {
		RED = 0.33,
		GREEN = 0.6,
		BLUE = 0.06,
		WHITE = 0.329,
	},
}

local function PutWithin0To255(N: number)
	return math.clamp(N, 0, 255)
end

-- http://alienryderflex.com/hsp.html
local function RGBToLum(R: number, G: number, B: number)
	return math.sqrt(
		(Pr * R * R) +
		(Pg * G * G) +
		(Pb * B * B)
	)
end

-- http://rgb2hsl.nichabi.com/javascript-function.php
local function RGBToHSL(R: number, G: number, B: number)
	R /= 255
	G /= 255
	B /= 255

	local Max = math.max(R, G, B)
	local Min = math.min(R, G, B)
	local L = (Max + Min) / 2

	if Max == Min then
		return 0, 0, RGBToLum(R, G, B)
	else
		local D = Max - Min
		local S = if L > 0.5 then D / (2 - Max - Min) else D / (Max + Min)
		local H = if Max == R then
				((G - B) / D) + (if G < B then 6 else 0)
			elseif Max == G then
				((B - R) / D) + 2
			elseif Max == B then
				((R - G) / D) + 4
			else
				0

		return (H / 6), S, RGBToLum(R, G, B)
	end
end

-- returns R, G, B
local function i32ToRGB(i32: number)
	return bit32.band(i32, 0xff), bit32.rshift(bit32.band(i32, 0xff00), 8),
		bit32.rshift(bit32.band(i32, 0xff0000), 16)
end

local function ExtractData(Data: {Color3} | EditableImage)
    if typeof(Data) == "Instance" then
        return EditableImage:ReadPixels(Vector2.new(), EditableImage.Size)
    elseif #Data > 0 then
        local NewData = table.create(#Data * 4, 0)

        for Index, Color3 in Data do
            local NewIndex = if Index ~= 1 then Index * 4 else 1
            NewData[NewIndex] = math.clamp((Color3.R * 255), 0, 255)
            NewData[NewIndex + 1] = math.clamp((Color3.G * 255), 0, 255)
            NewData[NewIndex + 2] = math.clamp((Color3.B * 255), 0, 255)
        end
        return NewData
    else
        error("[Quack] Extract data failed, array provided may have had 0 indexs")
    end
end

--------------------------------------------------------------------------------
-- Distance
--------------------------------------------------------------------------------

local function GetColorDiffrenceChannel(X: number, Y: number, Alphas: number)
    -- maximum of channel blended on white, and blended on black
    -- premultiplied alpha and backgrounds 0/1 shorten the formula
    local Black = X - Y
    local White = Black + Alphas
    return (Black * Black) + (White * White)
end

-- TODO: check quality of this distance equation
-- TODO: ask author for usage rights
-- taken from:
-- {@link http://stackoverflow.com/questions/4754506/color-similarity-distance-in-rgba-color-space/8796867#8796867}
-- {@link https://github.com/pornel/pngquant/blob/cc39b47799a7ff2ef17b529f9415ff6e6b213b8f/lib/pam.h#L148}
local function CalcuateRaw_PNGQuant(
    self: DistanceCalcuator,
    R1: number,
    G1: number,
    B1: number,
    A1: number,
    R2: number,
    G2: number,
    B2: number,
    A2: number
)
    --[[
        Author's comments
        px_b.rgb = px.rgb + 0*(1-px.a) // blend px on black
        px_b.a   = px.a   + 1*(1-px.a)
        px_w.rgb = px.rgb + 1*(1-px.a) // blend px on white
        px_w.a   = px.a   + 1*(1-px.a)

        px_b.rgb = px.rgb              // difference same as in opaque RGB
        px_b.a   = 1
        px_w.rgb = px.rgb - px.a       // difference simplifies to formula below
        px_w.a   = 1

        (px.rgb - px.a) - (py.rgb - py.a)
        (px.rgb - py.rgb) + (py.a - px.a)
    --]]
    local Alphas = (A2 - A1) * self.WhitepointA

    return GetColorDiffrenceChannel(
        R1 * self.WhitepointR,
        R2 * self.WhitepointR,
        Alphas
    ) +
    GetColorDiffrenceChannel(
        G1 * self.WhitepointG,
        G2 * self.WhitepointG,
        Alphas
    ) +
    GetColorDiffrenceChannel(
        B1 * self.WhitepointB,
        B2 * self.WhitepointB,
        Alphas
    )
end

-- Manhattan distance (NeuQuant modification) - w/o sRGB coefficients
local function CalcuateRaw_Manhattan(
    self: DistanceCalcuator,
    R1: number,
    G1: number,
    B1: number,
    A1: number,
    R2: number,
    G2: number,
    B2: number,
    A2: number
)
    local dR = R2 - R1
    local dG = G2 - G1
    local dB = B2 - B1
    local dA = A2 - A1
    if dR < 0 then dR = 0 - dR end
    if dG < 0 then dG = 0 - dG end
    if dB < 0 then dB = 0 - dB end
    if dA < 0 then dA = 0 - dA end

    return (self.Defaults.KR * dR) + (self.Defaults.KG * dG) + 
        (self.Defaults.KB * dB) + (self.Defaults.KA * dA)
end

local function CalcuateRaw_Euclidean(
    self: DistanceCalcuator,
    R1: number,
    G1: number,
    B1: number,
    A1: number,
    R2: number,
    G2: number,
    B2: number,
    A2: number,
)
    local dR = R2 - R1;
    local dG = G2 - G1;
    local dB = B2 - B1;
    local dA = A2 - A1;
    return math.sqrt(
        (self.Defaults.KR * dR * dR) +
        (self.Defaults.KG * dG * dG) +
        (self.Defaults.KB * dB * dB) +
        (self.Defaults.KA * dA * dA),
    )
end

local function CalcuateRaw_CMetric(
    self: DistanceCalcuator,
    R1: number,
    G1: number,
    B1: number,
    A1: number,
    R2: number,
    G2: number,
    B2: number,
    A2: number,
)
    local rmean = ((R1 + R2) / 2) * self.WhitepointR
    local r = (R1 - R2) * self.WhitepointR
    local g = (G1 - G2) * self.WhitepointG
    local b = (B1 - B2) * self.WhitepointB
    local dA = (A2 - A1) * self.WhitepointA
    local dE =
        (bit32.rshift(((512 + rmean) * r * r), 8)) +
        (bit32.rshift(((767 - rmean) * b * b), 8)) +
        (4 * g * g)

    return math.sqrt((dE + dA) * dA)
end

local Calcuators: {
    [DistanceFormula]: {
        Defualts: DistanceFormulaDefaults,
        CalcuateRaw: CalcuatorFunction,
    }
} = {
    Manhattan = {
        CalculateRaw = CalcuateRaw_Manhattan,
        Defualts = {
            KR = 1,
            KG = 1,
            KB = 1,
            KA = 1,
        },
    },
    -- Manhattan distance (Nommyde modification)
    -- https://github.com/igor-bezkrovny/image-quantization/issues/4#issuecomment-235155320
    ManhattanNommyde = {
        CalculateRaw = CalcuateRaw_Manhattan,
        Defualts = {
            KR = 0.4984,
            KG = 0.8625,
            KB = 0.2979,
            -- TODO: what is the best coefficient below?
            KA = 1,
        },
    },
    -- Manhattan distance (sRGB coefficients)
    ManhattanBT709 = {
        CalculateRaw = CalcuateRaw_Manhattan,
        Defualts = {
            KR = BT709.Y.RED,
            KG = BT709.Y.GREEN,
            KB = BT709.Y.BLUE,
            -- TODO: what is the best coefficient below?
            KA = 1,
        },
    },
    Euclidean = {
        CalculateRaw = CalcuateRaw_Euclidean,
        Defualts = {
            KR = 1,
            KG = 1,
            KB = 1,
            KA = 1,
        },
    },
    -- Euclidean color distance (RGBQuant modification w Alpha)
    EuclideanBT709 = {
        CalculateRaw = CalcuateRaw_Euclidean,
        Defualts = {
			KR = BT709.Y.RED,
            KG = BT709.Y.GREEN,
            KB = BT709.Y.BLUE,
            KA = 1,
        },
    },
    PNGQuant = {
        CalcuateRaw = CalcuateRaw_PNGQuant,
        Defualts = table.create(1) :: any,
    },
    CMetric = {
        CalculateRaw = CalcuateRaw_CMetric,
        Defualts = table.create(1) :: any,
    },
}

local CalcuatorPrototype = {}
CalcuatorPrototype.__index = CalcuatorPrototype

function CalcuatorPrototype.CalcuateNormalized(
    self: DistanceCalcuator,
    R1: number,
    G1: number,
    B1: number,
    A1: number,
    R2: number,
    G2: number,
    B2: number,
    A2: number
)
    return self:CalculateRaw(R1, G1, B1, A1, R2, G2, B2, A2) / self.MaxDistance
end

local function CreateCalcuator(
    DistanceFormula: DistanceFormula,
    R: number,
    G: number,
    B: number,
    A: number
)
    local Calcuator = Calcuators[DistanceFormula]
    if not Calcuator then
        error(`[Quack] No distance calcuator exists for {DistanceFormula}`, 2)
    end

    local self = setmetatable({
        WhitepointR = if R > 0 then 255 / R else 0,
        WhitepointG = if G > 0 then 255 / G else 0,
        WhitepointB = if B > 0 then 255 / B else 0,
        WhitepointA = if A > 0 then 255 / A else 0,
        CalculateRaw = Calcuator.CalculateRaw,
        Defualts = Calcuator.Defualts
    }, CalcuatorPrototype)
    self.MaxDistance = self:CalcuateRaw(R, G, B, A, 0, 0, 0, 0)
    return self :: DistanceCalcuator
end

--------------------------------------------------------------------------------
-- Dithering
--------------------------------------------------------------------------------

 -- http://www.tannerhelland.com/4660/dithering-eleven-algorithms-source-code/
local ErrorDiffusionArrays: {[DitheringMethod]: {{number}}} = {
	FloydSteinberg = {
		{7 / 16, 1, 0},
		{3 / 16, -1, 1},
		{5 / 16, 0, 1},
		{1 / 16, 1, 1}
	},
	FalseFloydSteinberg = {
		{3 / 8, 1, 0},
		{3 / 8, 0, 1},
		{2 / 8, 1, 1}
	},
	Stucki = {
		{8 / 42, 1, 0},
		{4 / 42, 2, 0},
		{2 / 42, -2, 1},
		{4 / 42, -1, 1},
		{8 / 42, 0, 1},
		{4 / 42, 1, 1},
		{2 / 42, 2, 1},
		{1 / 42, -2, 2},
		{2 / 42, -1, 2},
		{4 / 42, 0, 2},
		{2 / 42, 1, 2},
		{1 / 42, 2, 2}
	},
	Atkinson = {
		{1 / 8, 1, 0},
		{1 / 8, 2, 0},
		{1 / 8, -1, 1},
		{1 / 8, 0, 1},
		{1 / 8, 1, 1},
		{1 / 8, 0, 2}
	},
	-- Jarvis, Judice, and Ninke / JJN?
	Jarvis = {
		{7 / 48, 1, 0},
		{5 / 48, 2, 0},
		{3 / 48, -2, 1},
		{5 / 48, -1, 1},
		{7 / 48, 0, 1},
		{5 / 48, 1, 1},
		{3 / 48, 2, 1},
		{1 / 48, -2, 2},
		{3 / 48, -1, 2},
		{5 / 48, 0, 2},
		{3 / 48, 1, 2},
		{1 / 48, 2, 2}
	},
	Burkes = {
		{8 / 32, 1, 0},
		{4 / 32, 2, 0},
		{2 / 32, -2, 1},
		{4 / 32, -1, 1},
		{8 / 32, 0, 1},
		{4 / 32, 1, 1},
		{2 / 32, 2, 1},
	},
	Sierra = {
		{5 / 32, 1, 0},
		{3 / 32, 2, 0},
		{2 / 32, -2, 1},
		{4 / 32, -1, 1},
		{5 / 32, 0, 1},
		{4 / 32, 1, 1},
		{2 / 32, 2, 1},
		{2 / 32, -1, 2},
		{3 / 32, 0, 2},
		{2 / 32, 1, 2},
	},
	TwoSierra = {
		{4 / 16, 1, 0},
		{3 / 16, 2, 0},
		{1 / 16, -2, 1},
		{2 / 16, -1, 1},
		{3 / 16, 0, 1},
		{2 / 16, 1, 1},
		{1 / 16, 2, 1},
	},
	SierraLite = {
		{2 / 4, 1, 0},
		{1 / 4, -1, 1},
		{1 / 4, 0, 1},
	},
}

local HilbertRight = 3
local HilbertDown = 4
local HilbertNone = 0
local HilbertLeft = 2
local HilbertUp = 1

local function FillErrorLine(ErrorLine: {{number}}, Width: number)
	-- shrink
	local Length = if #ErrorLine > Width then Width else #ErrorLine

	-- reuse existing arrays
	if #ErrorLine ~= 0 then
		for Index = 1, Length do
			local Error = ErrorLine[Index]
			Error[1] = 0
			Error[2] = 0
			Error[3] = 0
			Error[4] = 0
		end
	end

	-- create missing arrays
	for Index = Length + 1, Width do
		ErrorLine[Index] = table.create(4, 0.0)
	end
	return ErrorLine
end

-- adapted from http://jsbin.com/iXofIji/2/edit by PAEz
-- fixed version. it doesn't use image pixels as error storage, also it doesn't have 0.3 + 0.3 + 0.3 + 0.3 = 0 error
-- Mutates ImageData
local function Dither_ErrorDiffusionArray(
	DistanceCalcuator: DistanceCalcuator,
	ImageData: ImageData,
	Palette: Palette,
	DitheringMethod: DitheringMethod,
	Serpentine: boolean?,
	MinimumColorDistanceToDither: number?,
	CalculateErrorLikeGIMP: boolean?,
)
	local Kernels = ErrorDiffusionArrays[DitheringMethod] :: {{number}}
	if not Kernels then
		error(`[Quack] Could not find Error Diffusion Kernel for {DitheringMethod}`)
	end

	local Height = ImageData.Height
	local Width = ImageData.Width
	local MaxErrorLines = 1
	local OriginalR
	local OriginalG
	local OriginalB
	local OriginalA

	for _, Kernel in Kernels do
		local KernelErrorLines = Kernel[3] + 1
		
		if KernelErrorLines > MaxErrorLines then
			MaxErrorLines = KernelErrorLines
		end
	end
	local ErrorLines = table.create(MaxErrorLines)
	local Dir = 1

	for Index = 1, MaxErrorLines do
		ErrorLines[Index] = FillErrorLine({}, Width)
	end

	for Y = 1, Height do
		if Serpentine then
			Dir *= -1
		end
		local lni = Y * Width
		local XStart = if Dir == 1 then 0 else Width - 1
		local XEnd = if Dir == 1 then Width else -1

		-- cyclic shift with erasing
		FillErrorLine(ErrorLines[1], Width)
		table.insert(ErrorLines, table.remove(ErrorLines, 1) :: any)
		local ErrorLine = ErrorLines[1]
		local Index = lni + XStart

		for X = XStart, XEnd do
			-- Image pixel
			local Point = pointArray[idx];
			local Error = ErrorLine[X]

			OriginalR = Point[1]
			OriginalG = Point[2]
			OriginalB = Point[3]
			OriginalA = Point[4]

			local CorrectedR = OriginalR + Error[1]
			local CorrectedG = OriginalG + Error[2]
			local CorrectedB = OriginalB + Error[3]
			local CorrectedA = OriginalA + Error[4]

			-- Reduced pixel
			local PaletteR, PaletteG, PaletteB, PaletteA = Palette:NearestColor(
				DistanceCalcuator,
				CorrectedR,
				CorrectedG,
				CorrectedB,
				CorrectedA
			)
			Point[1] = PaletteR
			Point[2] = PaletteG
			Point[3] = PaletteB
			Point[4] = PaletteA

			-- dithering strength
			if MinimumColorDistanceToDither then 
				local Distance = DistanceCalcuator:CalcuateNormalized(
					OriginalR,
					OriginalG,
					OriginalB,
					OriginalA,
					PaletteR,
					PaletteG,
					PaletteB,
					PaletteA
				)
				if Distance < MinimumColorDistanceToDither then continue end
			end

			local ER
			local EG
			local EB
			local EA

			if CalculateErrorLikeGIMP then
				ER = CorrectedR - PaletteR
				EG = CorrectedG - PaletteG
				EB = CorrectedB - PaletteB
				EA = CorrectedA - PaletteA
			else
				ER = OriginalR - PaletteR
				EG = OriginalG - PaletteG
				EB = OriginalB - PaletteB
				EA = OriginalA - PaletteA
			end

			local DStart = if Dir == 1 then 0 else #Kernels - 1
			local DEnd = if Dir == 1 then #Kernels else -1

			for I = DStart, DEnd, Dir do
				local X1 = Kernels[I][2] * Dir
				local Y1 = Kernels[I][3]
	  
				if 
					X1 + X >= 0 and X1 + X < Width and
					Y1 + Y >= 0 and Y1 + Y < Height
				then
					local E = ErrorLines[Y1][X1 + X]
					local D = Kernels[I][1]
					
					E[1] += ER * D
					E[2] += EG * D
					E[3] += EB * D
					E[4] += EA * D
				end
			end
			Index += Dir
		end
	end
end

local HilbertCurvePrototype = {}
HilbertCurvePrototype.__index = HilbertCurvePrototype

function HilbertCurvePrototype.Visit(self: HilbertCurve, Direction: number)
	if 
		self.X >= 0 and self.X < self.Width and 
		self.Y >= 0 and self.Y < self.Height 
	then
		self.Callback(self.X, self.Y)
	end
	
	if Direction == HilbertLeft then
		self.X -= 1
	elseif Direction == HilbertRight then
		self.X += 1
	elseif Direction == HilbertUp then
		self.Y -= 1
	elseif Direction == HilbertDown then
		self.Y += 1
	end
end

function HilbertCurvePrototype.Walk(self: HilbertCurve, Direction: number)
	if self.Level < 1 then return end
	self.Level -= 1
	
	if Direction == HilbertLeft then
		self:Walk(HilbertUp)
		self:Visit(HilbertRight)
		self:Walk(HilbertLeft)
		self:Visit(HilbertDown)
		self:Walk(HilbertLeft)
		self:Visit(HilbertLeft)
		self:Walk(HilbertDown)
	elseif Direction == HilbertRight then
		self:Walk(HilbertDown)
		self:Visit(HilbertLeft)
		self:Walk(HilbertRight)
		self:Visit(HilbertUp)
		self:Walk(HilbertRight)
		self:Visit(HilbertRight)
		self:Walk(HilbertUp)
	elseif Direction == HilbertUp then
		self:Walk(HilbertLeft)
		self:Visit(HilbertDown)
		self:Walk(HilbertUp)
		self:Visit(HilbertRight)
		self:Walk(HilbertUp)
		self:Visit(HilbertUp)
		self:Walk(HilbertRight)
	elseif Direction == HilbertDown then
		self:Walk(HilbertRight)
		self:Visit(HilbertUp)
		self:Walk(HilbertDown)
		self:Visit(HilbertLeft)
		self:Walk(HilbertDown)
		self:Visit(HilbertDown)
		self:Walk(HilbertLeft)
	end
	self.Level += 1
end

local function Dither_ErrorDiffusionRiemersma(
	DistanceCalcuator: DistanceCalcuator,
	ImageData: ImageData,
	Palette: Palette,
	ErrorPropagation: number?,
	ErrorQueueSize: number?,
)
	local ErrorPropagation = ErrorPropagation or 1	
	local ErrorQueueSize = ErrorQueueSize or 16

	local Multiplier = math.exp(math.log(ErrorQueueSize) / (ErrorQueueSize - 1))
	local pointArray = pointContainer.getPointArray();
	local ErrorQueue = table.create(ErrorQueueSize)
	local Weights = table.create(ErrorQueueSize)
	local Height = ImageData.Height
	local Width = ImageData.Width
	local Head = 0
	local Next = 1

	for Index = 1, ErrorQueueSize do
		Weights[Index] = (bit32.bor(Next + 0.5, 0) / ErrorQueueSize) * ErrorPropagation
		ErrorQueue[Index] = table.create(4, 0)
		Next *= Multiplier
	end

	local HilbertCurve: HilbertCurve = setmetatable({
		Callback = function(X, Y)
			local P = pointArray[(X + Y) * Width]
			local R = P[1]
			local G = P[2]
			local B = P[3]
			local A = P[4]
	
			for Index, Weight in Weights do
				local Error = ErrorQueue[(Index + Head) % ErrorQueueSize]
	
				R += Error[1] * Weight
				G += Error[2] * Weight
				B += Error[3] * Weight
				A += Error[4] * Weight
			end
			-- QuantizedPoint
			local QuantizedR, QuantizedG, QuantizedB, QuantizedA = Palette:NearestColor(
				DistanceCalcuator,
				math.clamp(R, 0, 255),
				math.clamp(G, 0, 255),
				math.clamp(B, 0, 255),
				math.clamp(A, 0, 255)
			)
		
			-- update head and calculate tail
			Head = (Head + 1) % ErrorQueueSize
			local Tail = ((Head + ErrorQueueSize) - 1) % ErrorQueueSize
		
			-- update error with new value
			ErrorQueue[Tail][1] = R - QuantizedR
			ErrorQueue[Tail][2] = G - QuantizedG
			ErrorQueue[Tail][3] = B - QuantizedB
			ErrorQueue[Tail][4] = A - QuantizedA
		
			-- update point
			--p.from(quantizedPoint);
			P[1] = QuantizedR
			P[2] = QuantizedG
			P[3] = QuantizedB
			P[4] = QuantizedA
		end,

		Level = math.floor(math.log(math.max(Width, Height)) / math.log(2) + 1),
		Height = Height,
		Width = Width,
		X = 0,
		Y = 0,
	}, HilbertCurvePrototype) :: any

	HilbertCurve:Walk(HilbertUp)
	HilbertCurve:Visit(0)
end

-- PointContainer is replaced w image data, a simple struct
local function Dither_NearestColor(
	DistanceCalcuator: DistanceCalcuator,
	ImageData: ImageData,
	Palette: Palette,
)
	local pointArray = pointContainer.getPointArray();

	for Y = 1, ImageData.Height do
		local Index = Y * ImageData.Width

		for X = 1, ImageData.Width do
			-- Image pixel
			local Point = pointArray[Index]

			-- Reduced pixel
			local QuantizedR, QuantizedG, QuantizedB, QuantizedA = Palette:NearestColor(
				DistanceCalcuator,
				table.unpack(Point)
			)

			Point[1] = QuantizedR
			Point[2] = QuantizedG
			Point[3] = QuantizedB
			Point[4] = QuantizedA
			Index += 1
		end
	end
end

local QuantizerPrototype = {}
QuantizerPrototype.__index = QuantizerPrototype

-- TOTRY: use HUSL - http://boronine.com/husl/
function QuantizerPrototype.__nearest_index(
	self: QuantizerInternal,
	i32: number,
	GetDistance: typeof(EuclideanDistance) | typeof(ManhattanDistance)?,
): number?
	-- alpha 0 returns null index
	if bit32.rshift(bit32.band(i32, 0xff000000), 24) == 0 then
		return nil
	elseif self.useCache and self.i32idx[i32] then
		return self.i32idx[i32]
	end
	
	GetDistance = GetDistance or self.__get_distance
	local ClosestDistance = math.huge
	local R, G, B = i32ToRGB(i32)
	local ClosestIndex = nil

	for Index = 0, buffer.len(self.idxrgb), 3 do
		local Distance  = GetDistance(
			R, G, B,
			buffer.readu8(self.idxrgb, Index),
			buffer.readu8(self.idxrgb, Index + 1),
			buffer.readu8(self.idxrgb, Index + 2),
		)
		
		if Distance < ClosestDistance then
			ClosestDistance = Distance,
			ClosestIndex = Index
		end
	end

	return ClosestIndex
end

-- TOTRY: use HUSL - http:--boronine.com/husl/
function QuantizerPrototype.__nearest_color(self: QuantizerInternal, i32: number)
	local Index = self:__nearest_index(i32)
	return if Index == nil then 0 else self.idxi32[idx]
end

-- adapted from http://jsbin.com/iXofIji/2/edit by PAEz
local function Dither(
	ImageData: ImageData,
	Kernel: DitheringKernel,
	DistanceEquation: DistanceEquation?,
	Serpentine: boolean?,
	Delta: number?,
	Quantizer: Quantizer?,
)
	local DataSet = DitheringKernels[Kernel] -- also known as ds in js ver
	local DistanceDelta = Delta or 0

	if DistanceDelta > 1 or DistanceDelta < 0 then
		error(`[Quanty] Delta is not in range 0..1"`)
	elseif not DataSet then
		error(`[Quanty] Unknown dithering kernel provided "{Kernel}"`)
	end
	local GetDistance = if DistanceEquation == "Manhattan" then ManhattanDistance else EuclideanDistance 
	local Direction = if Serpentine then -1 else 1
	local Height = ImageData.Height
	local Width = ImageData.Width

	-- CHANGE TO ACTUAL CLASS EVENTUALLY
	local Quantizer = Quantizer or somemethodtomakeaquantizer

	for Y = 1, Height do
		if Serpentine then
			Direction *= -1
		end

		local lni = Y * Width

		for X = (if Direction == 1 then 1 else Width - 1), 
			(if Direction == 1 then Width else 0), 
			Direction 
		do
			-- Image pixel
			local Index = ((Y * Width) + X) - 1
			local i32 = buffer.readi32(ImageData.Pixels, Index)
			local R1, G1, B1 = i32ToRGB(i32)

			-- Reduced pixel
			local i32X = Quantizer:__nearest_index(i32)
			local R2, G2, B2 = i32ToRGB(i32X)

			buffer.writei32(ImageData.Pixels, Index, bit32.bor(
				bit32.lshift(255, 24), -- alpha
				bit32.lshift(B2, 16), -- blue
				bit32.lshift(G2, 8), -- green
				R2
			))

			-- dithering strength
			if DistanceDelta > 0 then
				if GetDistance(R1, G1, B1, R2, G2, B2) > DistanceDelta then continue end
			end

			-- Component distance
			local ER = R1 - R2
			local EG = G1 - G2
			local EB = B1 - B2

			for I = (if Direction == 1 then 0 else #DataSet - 1), Direction do
				if I ~= (if Direction == 1 then #DataSet else 0) then break end
				local X1 = DataSet[I][2] * Direction
				local Y1 = DataSet[I][3]

				if X1 + X >= 0 and X1 + X < Width and Y1 + Y >= 0 and Y1 + Y < Height then
					local Index2 = Index + ((Y1 * Width) + X1)
					local D = DataSet[I][1]

					local R3, G3, B3 = i32ToRGB(buffer.readi32(ImageData.Pixels, Index))

					buffer.writei32(ImageData.Pixels, Index2, bit32.bor(
						bit32.lshift(255, 24), -- alpha
						bit32.lshift(math.max(0, math.min(255, (B3 + EB) * D)), 16), -- blue
						bit32.lshift(math.max(0, math.min(255, (G3 + EG) * D)), 8), -- green
						math.max(0, math.min(255, (R3 + ER) * D)) -- red
					))
				end
			end
		end
	end
	return ImageData.Pixels
end

-- gathers histogram info
function Quantizer.Sample(self: QuantizerInternal, ImageData: ImageData)
	if self.Method == "GlobalPopulation" then
		var histG = this.histogram,
		num = 0, col,
		len = buf32.length;

		for (var i = 0; i < len; i++) {
			col = buf32[i];

			-- skip transparent
			if ((col & 0xff000000) >> 24 == 0) continue;

			-- collect hue stats
			if (this.hueStats)
				this.hueStats.check(col);

			if (col in histG)
				histG[col]++;
			else
				histG[col] = 1;
		}
	else
		-- population threshold within subregions
		-- FIXME: this can over-reduce (few/no colors same?), need a way to keep
		-- important colors that dont ever reach local thresholds (gradients?)
		var boxW = this.boxSize[0],
			boxH = this.boxSize[1],
			area = boxW * boxH,
			boxes = makeBoxes(width, buf32.length / width, boxW, boxH),
			histG = this.histogram,
			self = this;

		boxes.forEach(function(box) {
			var effc = Math.max(Math.round((box.w * box.h) / area) * self.boxPxls, 2),
				histL = {}, col;

			iterBox(box, width, function(i) {
				col = buf32[i];

				-- skip transparent
				if ((col & 0xff000000) >> 24 == 0) return;

				-- collect hue stats
				if (self.hueStats)
					self.hueStats.check(col);

				if (col in histG)
					histG[col]++;
				else if (col in histL) {
					if (++histL[col] >= effc)
						histG[col] = histL[col];
				}
				else
					histL[col] = 1;
			});
		});

		if (this.hueStats)
			this.hueStats.inject(histG);
	end
end



(function(){
	function RgbQuant(opts) {
		opts = opts or {};

		-- 1 = by global population, 2 = subregion population threshold
		this.method = opts.method or 2;
		-- desired final palette size
		this.colors = opts.colors or 256;
		-- # of highest-frequency colors to start with for palette reduction
		this.initColors = opts.initColors or 4096;
		-- color-distance threshold for initial reduction pass
		this.initDist = opts.initDist or 0.01;
		-- subsequent passes threshold
		this.distIncr = opts.distIncr or 0.005;
		-- palette grouping
		this.hueGroups = opts.hueGroups or 10;
		this.satGroups = opts.satGroups or 10;
		this.lumGroups = opts.lumGroups or 10;
		-- if > 0, enables hues stats and min-color retention per group
		this.minHueCols = opts.minHueCols or 0;
		-- HueStats instance
		this.hueStats = this.minHueCols ? new HueStats(this.hueGroups, this.minHueCols) : null;

		-- subregion partitioning box size
		this.boxSize = opts.boxSize or [64,64];
		-- number of same pixels required within box for histogram inclusion
		this.boxPxls = opts.boxPxls or 2;
		-- palette locked indicator
		this.palLocked = false;
		-- palette sort order
--		this.sortPal = ['hue-','lum-','sat-'];

		-- dithering/error diffusion kernel name
		this.dithKern = opts.dithKern or null;
		-- dither serpentine pattern
		this.dithSerp = opts.dithSerp or false;
		-- minimum color difference (0-1) needed to dither
		this.dithDelta = opts.dithDelta or 0;

		-- accumulated histogram
		this.histogram = {};
		-- palette - rgb triplets
		this.idxrgb = opts.palette ? opts.palette.slice(0) : [];
		-- palette - int32 vals
		this.idxi32 = [];
		-- reverse lookup {i32:idx}
		this.i32idx = {};
		-- {i32:rgb}
		this.i32rgb = {};
		-- enable color caching (also incurs overhead of cache misses and cache building)
		this.useCache = opts.useCache !== false;
		-- min color occurance count needed to qualify for caching
		this.cacheFreq = opts.cacheFreq or 10;
		-- allows pre-defined palettes to be re-indexed (enabling palette compacting and sorting)
		this.reIndex = opts.reIndex or this.idxrgb.length == 0;
		-- selection of color-distance equation
		this.colorDist = opts.colorDist == "manhattan" ? distManhattan : distEuclidean;

		-- if pre-defined palette, build lookups
		if (this.idxrgb.length > 0) {
			var self = this;
			this.idxrgb.forEach(function(rgb, i) {
				var i32 = (
					(255    << 24) |	-- alpha
					(rgb[2] << 16) |	-- blue
					(rgb[1] <<  8) |	-- green
					 rgb[0]				-- red
				) >>> 0;

				self.idxi32[i]		= i32;
				self.i32idx[i32]	= i;
				self.i32rgb[i32]	= rgb;
			});
		}
	}

	-- image quantizer
	-- todo: memoize colors here also
	-- @retType: 1 - Uint8Array (default), 2 - Indexed array, 3 - Match @img type (unimplemented, todo)
	RgbQuant.prototype.reduce = function reduce(img, retType, dithKern, dithSerp) {
		if (!this.palLocked)
			this.buildPal();

		dithKern = dithKern or this.dithKern;
		dithSerp = typeof dithSerp != "undefined" ? dithSerp : this.dithSerp;

		retType = retType or 1;

		-- reduce w/dither
		if (dithKern)
			var out32 = this.dither(img, dithKern, dithSerp);
		else {
			var data = getImageData(img),
				buf32 = data.buf32,
				len = buf32.length,
				out32 = new Uint32Array(len);

			for (var i = 0; i < len; i++) {
				var i32 = buf32[i];
				out32[i] = this.nearestColor(i32);
			}
		}

		if (retType == 1)
			return new Uint8Array(out32.buffer);

		if (retType == 2) {
			var out = [],
				len = out32.length;

			for (var i = 0; i < len; i++) {
				var i32 = out32[i];
				out[i] = this.i32idx[i32];
			}

			return out;
		}
	};

	-- reduces histogram to palette, remaps & memoizes reduced colors
	RgbQuant.prototype.buildPal = function buildPal(noSort) {
		if (this.palLocked or this.idxrgb.length > 0 and this.idxrgb.length <= this.colors) return;

		var histG  = this.histogram,
			sorted = sortedHashKeys(histG, true);

		if (sorted.length == 0)
			throw "Nothing has been sampled, palette cannot be built.";

		switch (this.method) {
			case 1:
				var cols = this.initColors,
					last = sorted[cols - 1],
					freq = histG[last];

				var idxi32 = sorted.slice(0, cols);

				-- add any cut off colors with same freq as last
				var pos = cols, len = sorted.length;
				while (pos < len and histG[sorted[pos]] == freq)
					idxi32.push(sorted[pos++]);

				-- inject min huegroup colors
				if (this.hueStats)
					this.hueStats.inject(idxi32);

				break;
			case 2:
				var idxi32 = sorted;
				break;
		}

		-- int32-ify values
		idxi32 = idxi32.map(function(v){return +v;});

		this.reducePal(idxi32);

		if (!noSort and this.reIndex)
			this.sortPal();

		-- build cache of top histogram colors
		if this.useCache then
			for (var i = 0, i32 = idxi32[i]; i < idxi32.length and this.histogram[i32] >= this.cacheFreq; i32 = idxi32[i++])
				this.i32idx[i32] = this.nearestIndex(i32)
			end
		end

		this.palLocked = true;
	};

	RgbQuant.prototype.palette = function palette(tuples, noSort) {
		this.buildPal(noSort);
		return tuples ? this.idxrgb : new Uint8Array((new Uint32Array(this.idxi32)).buffer);
	};

	RgbQuant.prototype.prunePal = function prunePal(keep) {
		var i32;

		for (var j = 0; j < this.idxrgb.length; j++) {
			if (!keep[j]) {
				i32 = this.idxi32[j];
				this.idxrgb[j] = null;
				this.idxi32[j] = null;
				delete this.i32idx[i32];
			}
		}

		-- compact
		if (this.reIndex) {
			var idxrgb = [],
				idxi32 = [],
				i32idx = {};

			for (var j = 0, i = 0; j < this.idxrgb.length; j++) {
				if (this.idxrgb[j]) {
					i32 = this.idxi32[j];
					idxrgb[i] = this.idxrgb[j];
					i32idx[i32] = i;
					idxi32[i] = i32;
					i++;
				}
			}

			this.idxrgb = idxrgb;
			this.idxi32 = idxi32;
			this.i32idx = i32idx;
		}
	};

	-- reduces similar colors from an importance-sorted Uint32 rgba array
	RgbQuant.prototype.reducePal = function reducePal(idxi32) {
		-- if pre-defined palette's length exceeds target
		if (this.idxrgb.length > this.colors) {
			-- quantize histogram to existing palette
			var len = idxi32.length, keep = {}, uniques = 0, idx, pruned = false;

			for (var i = 0; i < len; i++) {
				-- palette length reached, unset all remaining colors (sparse palette)
				if (uniques == this.colors and !pruned) {
					this.prunePal(keep);
					pruned = true;
				}

				idx = this.nearestIndex(idxi32[i]);

				if (uniques < this.colors and !keep[idx]) {
					keep[idx] = true;
					uniques++;
				}
			}

			if (!pruned) {
				this.prunePal(keep);
				pruned = true;
			}
		}
		-- reduce histogram to create initial palette
		else {
			-- build full rgb palette
			var idxrgb = idxi32.map(function(i32) {
				return [
					(i32 & 0xff),
					(i32 & 0xff00) >> 8,
					(i32 & 0xff0000) >> 16,
				];
			});

			var len = idxrgb.length,
				palLen = len,
				thold = this.initDist;

			-- palette already at or below desired length
			if (palLen > this.colors) {
				while (palLen > this.colors) {
					var memDist = [];

					-- iterate palette
					for (var i = 0; i < len; i++) {
						var pxi = idxrgb[i], i32i = idxi32[i];
						if (!pxi) continue;

						for (var j = i + 1; j < len; j++) {
							var pxj = idxrgb[j], i32j = idxi32[j];
							if (!pxj) continue;

							var dist = this.colorDist(pxi, pxj);

							if (dist < thold) {
								-- store index,rgb,dist
								memDist.push([j, pxj, i32j, dist]);

								-- kill squashed value
								delete(idxrgb[j]);
								palLen--;
							}
						}
					}

					-- palette reduction pass
					-- console.log("palette length: " + palLen);

					-- if palette is still much larger than target, increment by larger initDist
					thold += (palLen > this.colors * 3) ? this.initDist : this.distIncr;
				}

				-- if palette is over-reduced, re-add removed colors with largest distances from last round
				if (palLen < this.colors) {
					-- sort descending
					sort.call(memDist, function(a,b) {
						return b[3] - a[3];
					});

					var k = 0;
					while (palLen < this.colors) {
						-- re-inject rgb into final palette
						idxrgb[memDist[k][0]] = memDist[k][1];

						palLen++;
						k++;
					}
				}
			}

			var len = idxrgb.length;
			for (var i = 0; i < len; i++) {
				if (!idxrgb[i]) continue;

				this.idxrgb.push(idxrgb[i]);
				this.idxi32.push(idxi32[i]);

				this.i32idx[idxi32[i]] = this.idxi32.length - 1;
				this.i32rgb[idxi32[i]] = idxrgb[i];
			}
		}
	};

	-- TODO: group very low lum and very high lum colors
	-- TODO: pass custom sort order
	local function SortPalette()

	end

	RgbQuant.prototype.sortPal = function sortPal() {
		var self = this;

		table.sort(self.idxi32, function(A, B)
		
		end)
		this.idxi32.sort(function(a,b) {
			var idxA = self.i32idx[a],
				idxB = self.i32idx[b],
				rgbA = self.idxrgb[idxA],
				rgbB = self.idxrgb[idxB];

			var hslA = rgb2hsl(rgbA[0],rgbA[1],rgbA[2]),
				hslB = rgb2hsl(rgbB[0],rgbB[1],rgbB[2]);

			-- sort all grays + whites together
			var hueA = (rgbA[0] == rgbA[1] and rgbA[1] == rgbA[2]) ? -1 : hueGroup(hslA.h, self.hueGroups);
			var hueB = (rgbB[0] == rgbB[1] and rgbB[1] == rgbB[2]) ? -1 : hueGroup(hslB.h, self.hueGroups);

			var hueDiff = hueB - hueA;
			if (hueDiff) return -hueDiff;

			var lumDiff = lumGroup(+hslB.l.toFixed(2)) - lumGroup(+hslA.l.toFixed(2));
			if (lumDiff) return -lumDiff;

			var satDiff = satGroup(+hslB.s.toFixed(2)) - satGroup(+hslA.s.toFixed(2));
			if (satDiff) return -satDiff;
		});

		-- sync idxrgb & i32idx
		this.idxi32.forEach(function(i32, i) {
			self.idxrgb[i] = self.i32rgb[i32];
			self.i32idx[i32] = i;
		});
	};

	function HueStats(numGroups, minCols) {
		this.numGroups = numGroups;
		this.minCols = minCols;
		this.stats = {};

		for (var i = -1; i < numGroups; i++)
			this.stats[i] = {num: 0, cols: []};

		this.groupsFull = 0;
	}

	HueStats.prototype.check = function checkHue(i32) {
		if (this.groupsFull == this.numGroups + 1)
			this.check = function() {return;};

		var r = (i32 & 0xff),
			g = (i32 & 0xff00) >> 8,
			b = (i32 & 0xff0000) >> 16,
			hg = (r == g and g == b) ? -1 : hueGroup(rgb2hsl(r,g,b).h, this.numGroups),
			gr = this.stats[hg],
			min = this.minCols;

		gr.num++;

		if (gr.num > min)
			return;
		if (gr.num == min)
			this.groupsFull++;

		if (gr.num <= min)
			this.stats[hg].cols.push(i32);
	};

	HueStats.prototype.inject = function injectHues(histG) {
		for (var i = -1; i < this.numGroups; i++) {
			if (this.stats[i].num <= this.minCols) {
				switch (typeOf(histG)) {
					case "Array":
						this.stats[i].cols.forEach(function(col){
							if (histG.indexOf(col) == -1)
								histG.push(col);
						});
						break;
					case "Object":
						this.stats[i].cols.forEach(function(col){
							if (!histG[col])
								histG[col] = 1;
							else
								histG[col]++;
						});
						break;
				}
			}
		}
	};

	function hueGroup(hue, segs) {
		var seg = 1/segs,
			haf = seg/2;

		if (hue >= 1 - haf or hue <= haf)
			return 0;

		for (var i = 1; i < segs; i++) {
			var mid = i*seg;
			if (hue >= mid - haf and hue <= mid + haf)
				return i;
		}
	}

	function satGroup(sat) {
		return sat;
	}

	function lumGroup(lum) {
		return lum;
	}

	function typeOf(val) {
		return Object.prototype.toString.call(val).slice(8,-1);
	}

	var sort = isArrSortStable() ? Array.prototype.sort : stableSort;



	local function GetPixelsData(Pixels: {number} | {{number}} | buffer, )

	-- partitions a rect of wid x hgt into
	-- array of bboxes of w0 x h0 (or less)
	function makeBoxes(wid, hgt, w0, h0) {
		var wnum = ~~(wid/w0), wrem = wid%w0,
			hnum = ~~(hgt/h0), hrem = hgt%h0,
			xend = wid-wrem, yend = hgt-hrem;

		var bxs = [];
		for (var y = 0; y < hgt; y += h0)
			for (var x = 0; x < wid; x += w0)
				bxs.push({x:x, y:y, w:(x==xend?wrem:w0), h:(y==yend?hrem:h0)});

		return bxs;
	}

	-- iterates @bbox within a parent rect of width @wid; calls @fn, passing index within parent
	function iterBox(bbox, wid, fn) {
		var b = bbox,
			i0 = b.y * wid + b.x,
			i1 = (b.y + b.h - 1) * wid + (b.x + b.w - 1),
			cnt = 0, incr = wid - b.w + 1, i = i0;

		do {
			fn.call(this, i);
			i += (++cnt % b.w == 0) ? incr : 1;
		} while (i <= i1);
	}

	-- returns array of hash keys sorted by their values
	function sortedHashKeys(obj, desc) {
		var keys = [];

		for (var key in obj)
			keys.push(key);

		return sort.call(keys, function(a,b) {
			return desc ? obj[b] - obj[a] : obj[a] - obj[b];
		});
	}

	-- expose
	this.RgbQuant = RgbQuant;

	-- expose to commonJS
	if (typeof module !== 'undefined' and module.exports) {
		module.exports = RgbQuant;
	}

}).call(this);

--[[
local Image1 = Quant.ExtractData(EditableImage)
local Image2 = Quack.ExtractData(EditableImage)
local Image3 = Quack.ExtractData(EditableImage)
Quack.ExtractDataFor(EditableImage1, EditableImage2, EditableImage3)

local Palette = Quack.PalletizeAsync(table.pack(Image1, Image2, Image3), {
	DitheringMethod = "FloydSteinberg",
	DistanceFormula = "Manhattan",
	Method = "GlobalPopulation",
	Colors = 256
}):Await()

local Palette = Quack.Palletize(Image, {
	DitheringMethod = "FloydSteinberg",
	DistanceFormula = "Manhattan",
	Method = "GlobalPopulation",
	Colors = 256
})

Quack.Dither("FloydSteinberg", Image)
--]]
