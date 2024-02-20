--!optimize 2
--!strict
--!native

-- Quack
-- A lightweight-ish color quantization library for luau
-- Based on image-quantization and RgbQuant
-- @Kalrnlo
-- 18/02/2024

-- TODO: Port over histogram class and other classes from image-quantization into luau
-- and remove usage of those closes for luau version as we are just having singular functions
-- and only using a palette class (hopefully) as a return for simplicity for quack users (it feels so weird saying quack users help)

--[[
local Image1 = Quant.ExtractData(EditableImage)
local Image2 = Quack.ExtractData(EditableImage)
local Image3 = Quack.ExtractData(EditableImage)
Quack.ExtractDataFor(EditableImage1, EditableImage2, EditableImage3)

Quack.Calcuator("Manhattan", 255, 255, 255, 0)

Quack.PalletizeAsync(table.pack(Image1, Image2, Image3), {
	DitheringMethod = "FloydSteinberg",
	DistanceFormula = "Manhattan",
	Method = "GlobalPopulation",
	Colors = 256
}):After(function(Palette)
	print(Palette.Colors[1])
end)

local Palette = Quack.Palletize(Image, {
	DitheringMethod = "FloydSteinberg",
	DistanceFormula = "Manhattan",
	Method = "GlobalPopulation",
	Colors = 256
})

Quack.Dither("FloydSteinberg", Image, Options)
--]]

local Future = require(script.Parent.Future)

type DitheringMethod = "FloydSteinberg" | "FalseFloydSteinberg" | "Stucki" | "Atkinson" |
	"Jarvis" | "Burkes" | "Sierra" | "TwoSierra" | "SierraLite" | 
	"ErrorDiffusionRiemersma" | "NearestColor"

type DistanceFormula = "Manhattan" | "Euclidean" | "ManhattanBT709" | "CMetric" |
	"ManhattanNommyde" | "EuclideanBT709" | "PNGQuant"

type Method = "GlobalPopulation" | "SubRegionPopulation"

type ReturnAs = "buffer" | "table" | "Color3" 

type Palletize = ((Image: ImageData, Options: PalletizeInfo) -> Palette<{}>) &
	((Images: {ImageData}, Options: PalletizeInfo) -> Palette<{}>) &
	((EditableImage: EditableImage, Options: PalletizeInfo) -> Palette<number>) &
	((EditableImages: {EditableImage}, Options: PalletizeInfo) -> Palette<number>)

type PalletizeInfo = DitheringInfo & {
	DistanceFormula: ("Manhattan" | "Euclidean" | "ManhattanBT709" | "CMetric" |
		"ManhattanNommyde" | "EuclideanBT709" | "PNGQuant")?,
	Method: ("GlobalPopulation" | "SubRegionPopulation")?,
}

type DitheringInfo = ({
		DitheringMethod: "NearestColor"?
	} & (ErrorDiffusionArrayInfo & {
		DitheringMethod: "FloydSteinberg" | "FalseFloydSteinberg" | "Stucki" | "Atkinson" |
			"Jarvis" | "Burkes" | "Sierra" | "TwoSierra" | "SierraLite"
	}) & (ErrorDiffusionRiemersmaInfo & {
		DitheringMethod: "ErrorDiffusionRiemersma"
	})
)

type ErrorDiffusionRiemersmaInfo = {
	ErrorPropagation: number?,
	ErrorQueueSize: number?,
}

type ErrorDiffusionArrayInfo = {
	MinimumColorDistanceToDither: number?,
	CalculateErrorLikeGIMP: boolean?,
	Serpentine: boolean?,
}

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

type PalettePrototype<T> = {
	Nearest: ((self: Palette<T>, R: number, G: number, B: number, A: number?) -> (number, number, number, number)) &
		((self: Palette<T>, Color3: Color3) -> (Color3, number)) &
		((self: Palette<T>, RGBOrRGBA: {number}) -> {number}) &
		((self: Palette<T>, buffer: buffer) -> buffer),
		
	-- tostring(Palette) returns the first color in the palette as a hex color string
	-- same with concat but part of the concatonaded string
	__concat: (self: Palette<T>, String: string) -> string,
	__tostring: (self: Palette<T>) -> string,
	__len: (self: Palette<T>) -> number,
}

type Palette<T> = typeof(setmetatable({} :: {
	Uint32Indexs: {number},
	Colors: {T}
}, {} :: PalettePrototype<T>))

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

-- TODO:
-- Luminance from RGB:

-- Luminance (standard for certain colour spaces): (0.2126*R + 0.7152*G + 0.0722*B) [1]
-- Luminance (perceived option 1): (0.299*R + 0.587*G + 0.114*B) [2]
-- Luminance (perceived option 2, slower to calculate):  sqrt( 0.241*R^2 + 0.691*G^2 + 0.068*B^2 ) ? sqrt( 0.299*R^2 + 0.587*G^2 + 0.114*B^2 ) (thanks to @MatthewHerbst) [http://alienryderflex.com/hsp.html]

local function GetRGBALuminosity(R: number, G: number, B: number, A: number?)
	if A then
		return (math.min(255, (255 - A + (A * R)) / 255) * Y.RED) +
			(math.min(255, (255 - A + (A * G)) / 255) * Y.GREEN) +
			(math.min(255, (255 - A + (A * B)) / 255) * Y.BLUE)
	else
		return (R * Y.RED) + (G * Y.GREEN) + (B * Y.BLUE)
	end
end

 -- how points get their unint (its a number idk why the lib uses a string, but we arent gonna be doin that)
 local function RGBAToUint32(R: number, G: number, B: number, A: number)
	return bit32.rshift(
		bit32.bor(bit32.lshift(A, 24), bit32.lshift(B, 16), bit32.lshift(G, 8), R), 0
	)
 end

-- https://stackoverflow.com/questions/62674500/getting-hex-from-rgba-in-js
local function RGBAToHex(R: number, G: number, B: number, A: number)
	local Outparts: {string} = {
		tonumber(R, 16),
		tonumber(G, 16),
		tonumber(B, 16),
		string.sub(tonumber(math.floor(A * 255), 16) :: any, 0, 2)
	} :: any
  
	-- Pad single-digit output values
	for Index, Number in Outparts do
		if #Number == 1 then 
			Outparts[Index] = `0{Number}`
		end
	end
	return `#{table.concat(Outparts)}`
end

local RGBToHSL(R: number, G: number, B: number)
	local Min = math.min(R, G, B)
	local Max = math.max(R, G, B)
	local L = (Min + Max) / 510
	local Delta = Max - Min

	local S = if L > 0 and L < 1 then 
			Delta / (if L < 0.5 then Max + Min else 510 - (Max - Min))
		else
			0
	local H = 0

	if Delta > 0 then
		H = (
			if Max == R then
				G - B / Delta
			elseif Max == G then
				(2 + (B - R)) / Delta
			else
				(4 + (R - G)) / Delta
		) * 60

		if H < 0 then
			H += 360
		end
	end
	return H, S, L
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

local f64Tou32 = bit32.band

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
        ((self.Defaults.KR * dR) * dR) +
        ((self.Defaults.KG * dG) * dG) +
        ((self.Defaults.KB * dB) * dB) +
        ((self.Defaults.KA * dA) * dA)
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
    local dA = (A2 - A1) * self.WhitepointA
    local r = (R1 - R2) * self.WhitepointR
    local g = (G1 - G2) * self.WhitepointG
    local b = (B1 - B2) * self.WhitepointB
    local dE = ((4 * g) * g) + 
		bit32.rshift((((512 + rmean) * r) * r), 8) +
        bit32.rshift((((767 - rmean) * b) * b), 8)

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
        Defualts = table.freeze({
            KR = 1,
            KG = 1,
            KB = 1,
            KA = 1,
        }),
    },
    -- Manhattan distance (Nommyde modification)
    -- https://github.com/igor-bezkrovny/image-quantization/issues/4#issuecomment-235155320
    ManhattanNommyde = {
        CalculateRaw = CalcuateRaw_Manhattan,
        Defualts = table.freeze({
            KR = 0.4984,
            KG = 0.8625,
            KB = 0.2979,
            -- TODO: what is the best coefficient below?
            KA = 1,
        }),
    },
    -- Manhattan distance (sRGB coefficients)
    ManhattanBT709 = {
        CalculateRaw = CalcuateRaw_Manhattan,
        Defualts = table.freeze({
            KR = BT709.Y.RED,
            KG = BT709.Y.GREEN,
            KB = BT709.Y.BLUE,
            -- TODO: what is the best coefficient below?
            KA = 1,
        }),
    },
    Euclidean = {
        CalculateRaw = CalcuateRaw_Euclidean,
        Defualts = table.freeze({
            KR = 1,
            KG = 1,
            KB = 1,
            KA = 1,
        }),
    },
    -- Euclidean color distance (RGBQuant modification w Alpha)
    EuclideanBT709 = {
        CalculateRaw = CalcuateRaw_Euclidean,
        Defualts = table.freeze({
			KR = BT709.Y.RED,
            KG = BT709.Y.GREEN,
            KB = BT709.Y.BLUE,
            KA = 1,
        }),
    },
    PNGQuant = {
        CalcuateRaw = CalcuateRaw_PNGQuant,
        Defualts = table.freeze({}) :: any,
    },
    CMetric = {
        CalculateRaw = CalcuateRaw_CMetric,
        Defualts = table.freeze({}) :: any,
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
		local ErrorLine = table.create(Width)

		for LineIndex = 1, Width do
			ErrorLine[LineIndex] = table.create(4, 0)
		end
		ErrorLines[Index] = ErrorLine
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

--------------------------------------------------------------------------------
-- Palette
--------------------------------------------------------------------------------

local PalettePrototype = {}
PalettePrototype.__index = PalettePrototype

function PalettePrototype.__concat<T>(self: Palette<T>, String: string)
	local Color = self.Colors[1]

	if Color then
		local Hex = RGBAToHex(
			buffer.readu8(Color, 0),
			buffer.readu8(Color, 1),
			buffer.readu8(Color, 2),
			buffer.readu8(Color, 3),
		)

		return `{String}{Hex}`
	else
		return `{String}#000000`
	end
end

function PalettePrototype.__tostring<T>(self: Palette<T>)
	local Color = self.Colors[1]

	if Color then
		return RGBAToHex(
			buffer.readu8(Color, 0),
			buffer.readu8(Color, 1),
			buffer.readu8(Color, 2),
			buffer.readu8(Color, 3),
		)
	else
		return "#000000"
	end
end

function PalettePrototype.__len<T>(self: Palette<T>)
	return #self.Colors
end

/*
 * Copyright (c) 2015, Leon Sorokin
 * All rights reserved. (MIT Licensed)
 *
 * ColorHistogram.js - an image quantization lib
 */

/**
 * @preserve TypeScript port:
 * Copyright 2015-2018 Igor Bezkrovnyi
 * All rights reserved. (MIT Licensed)
 *
 * colorHistogram.ts - part of Image Quantization Library
 */
 import { HueStatistics } from '../../utils/hueStatistics';
 import { PointContainer } from '../../utils/pointContainer';
 import { stableSort } from '../../utils/arithmetic';
 
 interface Box {
   x: number;
   y: number;
   h: number;
   w: number;
 }
 
 export class ColorHistogram {
   private static _boxSize = [64, 64];
   private static _boxPixels = 2;
   private static _hueGroups = 10;
 
   // 1 = by global population, 2 = subregion population threshold
   private _method: number;
 
   // HueStatistics instance
   private _hueStats: HueStatistics;
 
   private _histogram: { [color: string]: number };
 
   // # of highest-frequency colors to start with for palette reduction
   private _initColors: number;
 
   // if > 0, enables hues stats and min-color retention per group
   private _minHueCols: number;
 
   constructor(method: number, colors: number) {
	 // 1 = by global population, 2 = subregion population threshold
	 this._method = method;
 
	 // if > 0, enables hues stats and min-color retention per group
	 this._minHueCols = colors << 2; // opts.minHueCols || 0;
 
	 // # of highest-frequency colors to start with for palette reduction
	 this._initColors = colors << 2;
 
	 // HueStatistics instance
	 this._hueStats = new HueStatistics(
	   ColorHistogram._hueGroups,
	   this._minHueCols,
	 );
 
	 this._histogram = Object.create(null);
   }
 
   sample(pointContainer: PointContainer) {
	 switch (this._method) {
	   case 1:
		 this._colorStats1D(pointContainer);
		 break;
	   case 2:
		 this._colorStats2D(pointContainer);
		 break;
	 }
   }
 
   getImportanceSortedColorsIDXI32() {
	 // TODO: fix typing issue in stableSort func
	 const sorted = stableSort(
	   Object.keys(this._histogram),
	   (a, b) => this._histogram[b] - this._histogram[a],
	 );
	 if (sorted.length === 0) {
	   return [];
	 }
 
	 let idxi32;
	 switch (this._method) {
	   case 1:
		 const initialColorsLimit = Math.min(sorted.length, this._initColors);
		 const last = sorted[initialColorsLimit - 1];
		 const freq = this._histogram[last];
 
		 idxi32 = sorted.slice(0, initialColorsLimit);
 
		 // add any cut off colors with same freq as last
		 let pos = initialColorsLimit;
		 const len = sorted.length;
		 while (pos < len && this._histogram[sorted[pos]] === freq) {
		   idxi32.push(sorted[pos++]);
		 }
 
		 // inject min huegroup colors
		 this._hueStats.injectIntoArray(idxi32);
		 break;
 
	   case 2:
		 idxi32 = sorted;
		 break;
 
	   default:
		 // TODO: rethink errors
		 throw new Error('Incorrect method');
	 }
 
	 // int32-ify values
	 return idxi32.map((v) => +v);
   }
 
   // global top-population
   private _colorStats1D(pointContainer: PointContainer) {
	 const histG = this._histogram;
	 const pointArray = pointContainer.getPointArray();
	 const len = pointArray.length;
 
	 for (let i = 0; i < len; i++) {
	   const col = pointArray[i].uint32;
 
	   // collect hue stats
	   this._hueStats.check(col);
 
	   if (col in histG) {
		 histG[col]++;
	   } else {
		 histG[col] = 1;
	   }
	 }
   }
 
   // population threshold within subregions
   // FIXME: this can over-reduce (few/no colors same?), need a way to keep
   // important colors that dont ever reach local thresholds (gradients?)
   private _colorStats2D(pointContainer: PointContainer) {
	 const width = pointContainer.getWidth();
	 const height = pointContainer.getHeight();
	 const pointArray = pointContainer.getPointArray();
 
	 const boxW = ColorHistogram._boxSize[0];
	 const boxH = ColorHistogram._boxSize[1];
	 const area = boxW * boxH;
	 const boxes = this._makeBoxes(width, height, boxW, boxH);
	 const histG = this._histogram;
 
	 boxes.forEach((box) => {
	   let effc = Math.round((box.w * box.h) / area) * ColorHistogram._boxPixels;
	   if (effc < 2) effc = 2;
 
	   const histL: Record<string, number> = {};
	   this._iterateBox(box, width, (i) => {
		 const col = pointArray[i].uint32;
 
		 // collect hue stats
		 this._hueStats.check(col);
 
		 if (col in histG) {
		   histG[col]++;
		 } else if (col in histL) {
		   if (++histL[col] >= effc) {
			 histG[col] = histL[col];
		   }
		 } else {
		   histL[col] = 1;
		 }
	   });
	 });
 
	 // inject min huegroup colors
	 this._hueStats.injectIntoDictionary(histG);
   }
 
   // iterates @bbox within a parent rect of width @wid; calls @fn, passing index within parent
   private _iterateBox(bbox: Box, wid: number, fn: (i: number) => void) {
	 const b = bbox;
	 const i0 = b.y * wid + b.x;
	 const i1 = (b.y + b.h - 1) * wid + (b.x + b.w - 1);
	 const incr = wid - b.w + 1;
 
	 let cnt = 0;
	 let i = i0;
 
	 do {
	   fn.call(this, i);
	   i += ++cnt % b.w === 0 ? incr : 1;
	 } while (i <= i1);
   }
 
   /**
	*    partitions a rectangle of width x height into
	*    array of boxes stepX x stepY (or less)
	*/
   private _makeBoxes(
	 width: number,
	 height: number,
	 stepX: number,
	 stepY: number,
   ) {
	 const wrem = width % stepX;
	 const hrem = height % stepY;
	 const xend = width - wrem;
	 const yend = height - hrem;
	 const boxesArray = [];
 
	 for (let y = 0; y < height; y += stepY) {
	   for (let x = 0; x < width; x += stepX) {
		 boxesArray.push({
		   x,
		   y,
		   w: x === xend ? wrem : stepX,
		   h: y === yend ? hrem : stepY,
		 });
	   }
	 }
 
	 return boxesArray;
   }
 }

 /*
 * Copyright (c) 2015, Leon Sorokin
 * All rights reserved. (MIT Licensed)
 *
 * RGBQuant.js - an image quantization lib
 */

/**
 * @preserve TypeScript port:
 * Copyright 2015-2018 Igor Bezkrovnyi
 * All rights reserved. (MIT Licensed)
 *
 * rgbquant.ts - part of Image Quantization Library
 */

import { Palette } from '../../utils/palette';
import { Point } from '../../utils/point';
import { PointContainer } from '../../utils/pointContainer';
import { AbstractDistanceCalculator } from '../../distance/distanceCalculator';
import { ColorHistogram } from './colorHistogram';
import { AbstractPaletteQuantizer } from '../paletteQuantizer';
import { PaletteQuantizerYieldValue } from '../paletteQuantizerYieldValue';
import { stableSort } from '../../utils/arithmetic';
import { ProgressTracker } from '../../utils';

class RemovedColor {
  readonly index: number;
  readonly color: Point;
  readonly distance: number;

  constructor(index: number, color: Point, distance: number) {
    this.index = index;
    this.color = color;
    this.distance = distance;
  }
}

// TODO: make input/output image and input/output palettes with instances of class Point only!
export class RGBQuant extends AbstractPaletteQuantizer {
  // desired final palette size
  private readonly _colors: number;

  // color-distance threshold for initial reduction pass
  private readonly _initialDistance: number;

  // subsequent passes threshold
  private readonly _distanceIncrement: number;

  // accumulated histogram
  private readonly _histogram: ColorHistogram;
  private readonly _distance: AbstractDistanceCalculator;

  constructor(
    colorDistanceCalculator: AbstractDistanceCalculator,
    colors = 256,
    method = 2,
  ) {
    super();
    this._distance = colorDistanceCalculator;
    // desired final palette size
    this._colors = colors;

    // histogram to accumulate
    this._histogram = new ColorHistogram(method, colors);

    this._initialDistance = 0.01;
    this._distanceIncrement = 0.005;
  }

  // gathers histogram info
  sample(image: PointContainer) {
    /*
     var pointArray = image.getPointArray(), max = [0, 0, 0, 0], min = [255, 255, 255, 255];

     for (var i = 0, l = pointArray.length; i < l; i++) {
     var color = pointArray[i];
     for (var componentIndex = 0; componentIndex < 4; componentIndex++) {
     if (max[componentIndex] < color.rgba[componentIndex]) max[componentIndex] = color.rgba[componentIndex];
     if (min[componentIndex] > color.rgba[componentIndex]) min[componentIndex] = color.rgba[componentIndex];
     }
     }
     var rd = max[0] - min[0], gd = max[1] - min[1], bd = max[2] - min[2], ad = max[3] - min[3];
     this._distance.setWhitePoint(rd, gd, bd, ad);

     this._initialDistance = (Math.sqrt(rd * rd + gd * gd + bd * bd + ad * ad) / Math.sqrt(255 * 255 + 255 * 255 + 255 * 255)) * 0.01;
     */

    this._histogram.sample(image);
  }

  // reduces histogram to palette, remaps & memoizes reduced colors
  *quantize() {
    const idxi32 = this._histogram.getImportanceSortedColorsIDXI32();
    if (idxi32.length === 0) {
      throw new Error('No colors in image');
    }

    yield* this._buildPalette(idxi32);
  }

  // reduces similar colors from an importance-sorted Uint32 rgba array
  private *_buildPalette(
    idxi32: number[],
  ): IterableIterator<PaletteQuantizerYieldValue> {
    // reduce histogram to create initial palette
    // build full rgb palette
    const palette = new Palette();
    const colorArray = palette.getPointContainer().getPointArray();
    const usageArray = new Array(idxi32.length);

    for (let i = 0; i < idxi32.length; i++) {
      colorArray.push(Point.createByUint32(idxi32[i]));
      usageArray[i] = 1;
    }

    const len = colorArray.length;
    const memDist = [];

    let palLen = len;
    let thold = this._initialDistance;

    // palette already at or below desired length
    while (palLen > this._colors) {
      memDist.length = 0;

      // iterate palette
      for (let i = 0; i < len; i++) {
        if (usageArray[i] === 0) continue;
        const pxi = colorArray[i];
        // if (!pxi) continue;

        for (let j = i + 1; j < len; j++) {
          if (usageArray[j] === 0) continue;
          const pxj = colorArray[j];
          // if (!pxj) continue;

          const dist = this._distance.calculateNormalized(pxi, pxj);
          if (dist < thold) {
            // store index,rgb,dist
            memDist.push(new RemovedColor(j, pxj, dist));
            usageArray[j] = 0;
            palLen--;
          }
        }
      }
      // palette reduction pass
      // console.log("palette length: " + palLen);

      // if palette is still much larger than target, increment by larger initDist
      thold +=
        palLen > this._colors * 3
          ? this._initialDistance
          : this._distanceIncrement;
    }

    // if palette is over-reduced, re-add removed colors with largest distances from last round
    if (palLen < this._colors) {
      // sort descending
      stableSort(memDist, (a, b) => b.distance - a.distance);

      let k = 0;
      while (palLen < this._colors && k < memDist.length) {
        const removedColor = memDist[k];
        // re-inject rgb into final palette
        usageArray[removedColor.index] = 1;
        palLen++;
        k++;
      }
    }

    let colors = colorArray.length;
    for (let colorIndex = colors - 1; colorIndex >= 0; colorIndex--) {
      if (usageArray[colorIndex] === 0) {
        if (colorIndex !== colors - 1) {
          colorArray[colorIndex] = colorArray[colors - 1];
        }
        --colors;
      }
    }
    colorArray.length = colors;

    palette.sort();
  }
}

/*
 * Copyright (c) 2015, Leon Sorokin
 * All rights reserved. (MIT Licensed)
 *
 * RGBQuant.js - an image quantization lib
 */

/**
 * @preserve
 * Copyright 2015-2018 Igor Bezkrovnyi
 * All rights reserved. (MIT Licensed)
 *
 * palette.ts - part of Image Quantization Library
 */

 import { Point } from './point';
 import { PointContainer } from './pointContainer';
 import { AbstractDistanceCalculator } from '../distance/distanceCalculator';
 import { rgb2hsl } from '../conversion/rgb2hsl';
 
 // TODO: make paletteArray via pointContainer, so, export will be available via pointContainer.exportXXX
 
 const hueGroups = 10;
 
 export function hueGroup(hue: number, segmentsNumber: number) {
   const maxHue = 360;
   const seg = maxHue / segmentsNumber;
   const half = seg / 2;
 
   for (let i = 1, mid = seg - half; i < segmentsNumber; i++, mid += seg) {
	 if (hue >= mid && hue < mid + seg) return i;
   }
   return 0;
 }
 
 export class Palette {
   private readonly _pointContainer: PointContainer;
   private readonly _pointArray: Point[] = [];
   private _i32idx: { [key: string]: number } = {};
 
   constructor() {
	 this._pointContainer = new PointContainer();
	 this._pointContainer.setHeight(1);
	 this._pointArray = this._pointContainer.getPointArray();
   }
 
   add(color: Point) {
	 this._pointArray.push(color);
	 this._pointContainer.setWidth(this._pointArray.length);
   }
 
   has(color: Point) {
	 for (let i = this._pointArray.length - 1; i >= 0; i--) {
	   if (color.uint32 === this._pointArray[i].uint32) return true;
	 }
 
	 return false;
   }
 
   // TOTRY: use HUSL - http://boronine.com/husl/ http://www.husl-colors.org/ https://github.com/husl-colors/husl
   getNearestColor(
	 colorDistanceCalculator: AbstractDistanceCalculator,
	 color: Point,
   ) {
	 return this._pointArray[
	   this._getNearestIndex(colorDistanceCalculator, color) | 0
	 ];
   }
 
   getPointContainer() {
	 return this._pointContainer;
   }

 
   private _nearestPointFromCache(key: string) {
	 return typeof this._i32idx[key] === 'number' ? this._i32idx[key] : -1;
   }
 
   private _getNearestIndex(
	 colorDistanceCalculator: AbstractDistanceCalculator,
	 point: Point,
   ) {
	 let idx = this._nearestPointFromCache('' + point.uint32);
	 if (idx >= 0) return idx;
 
	 let minimalDistance = Number.MAX_VALUE;
 
	 idx = 0;
	 for (let i = 0, l = this._pointArray.length; i < l; i++) {
	   const p = this._pointArray[i];
	   const distance = colorDistanceCalculator.calculateRaw(
		 point.r,
		 point.g,
		 point.b,
		 point.a,
		 p.r,
		 p.g,
		 p.b,
		 p.a,
	   );
 
	   if (distance < minimalDistance) {
		 minimalDistance = distance;
		 idx = i;
	   }
	 }
 
	 this._i32idx[point.uint32] = idx;
	 return idx;
   }
 

 
   // TODO: group very low lum and very high lum colors
   // TODO: pass custom sort order
   // TODO: sort criteria function should be placed to HueStats class
   sort() {
	 this._i32idx = {};
	 this._pointArray.sort((a: Point, b: Point) => {
	   const hslA = rgb2hsl(a.r, a.g, a.b);
	   const hslB = rgb2hsl(b.r, b.g, b.b);
 
	   // sort all grays + whites together
	   const hueA =
		 a.r === a.g && a.g === a.b ? 0 : 1 + hueGroup(hslA.h, hueGroups);
	   const hueB =
		 b.r === b.g && b.g === b.b ? 0 : 1 + hueGroup(hslB.h, hueGroups);
	   /*
		var hueA = (a.r === a.g && a.g === a.b) ? 0 : 1 + Utils.hueGroup(hslA.h, hueGroups);
		var hueB = (b.r === b.g && b.g === b.b) ? 0 : 1 + Utils.hueGroup(hslB.h, hueGroups);
		*/
 
	   const hueDiff = hueB - hueA;
	   if (hueDiff) return -hueDiff;
 
	   /*
		var lumDiff = Utils.lumGroup(+hslB.l.toFixed(2)) - Utils.lumGroup(+hslA.l.toFixed(2));
		if (lumDiff) return -lumDiff;
		*/
	   const lA = a.getLuminosity(true);
	   const lB = b.getLuminosity(true);
 
	   if (lB - lA !== 0) return lB - lA;
 
	   const satDiff = ((hslB.s * 100) | 0) - ((hslA.s * 100) | 0);
	   if (satDiff) return -satDiff;
 
	   return 0;
	 });
   }
 }

 -- how points get their unint (its a number idk why the lib uses a string, but we arent gonna be doin that)
 private _loadUINT32() {
    this.uint32 =
      ((this.a << 24) | (this.b << 16) | (this.g << 8) | this.r) >>> 0;
  }