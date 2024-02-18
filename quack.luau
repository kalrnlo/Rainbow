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
<<<<<<< HEAD
        ((self.Defaults.KR * dR) * dR) +
        ((self.Defaults.KG * dG) * dG) +
        ((self.Defaults.KB * dB) * dB) +
        ((self.Defaults.KA * dA) * dA),
=======
        (self.Defaults.KR * dR * dR) +
        (self.Defaults.KG * dG * dG) +
        (self.Defaults.KB * dB * dB) +
        (self.Defaults.KA * dA * dA)
>>>>>>> c6fdcbd1a0daa30037ae048618bf6fe71c47ffe4
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
        (bit32.rshift((((512 + rmean) * r) * r), 8)) +
        (bit32.rshift((((767 - rmean) * b) * b), 8)) +
        ((4 * g) * g)

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
        error(`[Quack] No distance calcuator exists for {DistanceFormula}`, 3)
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
		ErrorLine[Index] = table.create(4, 0)
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

			local CorrectedR = math.clamp(OriginalR + Error[1], 0, 255)
			local CorrectedG = math.clamp(OriginalG + Error[2], 0, 255)
			local CorrectedB = math.clamp(OriginalB + Error[3], 0, 255)
			local CorrectedA = math.clamp(OriginalA + Error[4], 0, 255)

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

