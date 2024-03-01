--!optimize 2
--!strict
--!native

-- Quack
-- A lightweight-ish color quantization library for luau
-- Based on image-quantization and RgbQuant
-- @Kalrnlo
-- 27/02/2024

local ColorDistance = require(script.Parent.ColorDistance)
local ImageData = require(script.Parent.ImageData)
local Future = require(script.Parent.Future)

export type DitheringMethod = ArrayDitheringMethod | "ErrorDiffusionRiemersma" | "NearestColor"

export type DistanceFormula = "Manhattan" | "Euclidean" | "ManhattanBT709" | "CMetric" |
	"ManhattanNommyde" | "EuclideanBT709" | "PNGQuant"

export type Method = "GlobalPopulation" | "SubRegionPopulation"

export type PalletizeInfo = PaletteInfo & {
	Method: ("GlobalPopulation" | "SubRegionPopulation")?,
}

export type PaletteInfo = {
	DistanceFormula: ("Manhattan" | "Euclidean" | "ManhattanBT709" | "CMetric" |
		"ManhattanNommyde" | "EuclideanBT709" | "PNGQuant")?,
	MaxColors: number?,
	R: number?,
	G: number?,
	B: number?,
	A: number?,
}

export type DitheringInfo = {
		DitheringMethod: "NearestColor"?
	} | (ErrorDiffusionArrayInfo & {
		DitheringMethod: "FloydSteinberg" | "FalseFloydSteinberg" | "Stucki" | "Atkinson" |
			"Jarvis" | "Burkes" | "Sierra" | "TwoSierra" | "SierraLite",
	}) | (ErrorDiffusionRiemersmaInfo & {
		DitheringMethod: "ErrorDiffusionRiemersma",
	})

export type QuantizeInfo = DitheringInfo & PalletizeInfo

type ArrayDitheringMethod = "FloydSteinberg" | "FalseFloydSteinberg" | "Stucki" | "Atkinson" |
	"Jarvis" | "Burkes" | "Sierra" | "TwoSierra" | "SierraLite"

type ImageOrImages = {ImageData} | {EditableImage} | EditableImage | ImageData

type ErrorDiffusionRiemersmaInfo = {
	ErrorPropagation: number?,
	ErrorQueueSize: number?,
}

type ErrorDiffusionArrayInfo = {
	MinimumColorDistanceToDither: number?,
	CalculateErrorLikeGIMP: boolean?,
	Serpentine: boolean?,
}

type HueStatistics = {
	GroupAmount: number,
	GroupsFull: number,
	MinColors: number,
	Stats: {HueGroup},
}

type PaletteInfo = {
	DistanceFormula: DistanceFormula?,
	MaxColors: number?,
	R: number,
	G: number,
	B: number,
	A: number,
}

type HueGroup = {
	Colors: {number},
	Amount: number,
}

type DistanceFormulaDefaults = {
    KR: number,
    KG: number,
    KB: number,
    KA: number,   
}

type PalettePrototype = {
	Nearest: (self: Palette, R: number, G: number, B: number, A: number?) -> (number, number, number, number),
	Contains: (self: Palette, R: number, G: number, B: number, A: number?) -> boolean,
	Remove: ((self: Palette, R: number, G: number, B: number, A: number?) -> ()) &
		((self: Palette, Index: number) -> ()),
	__iter: (self: Palette) -> () -> (number, number, number, number, number),
	Add: (self: Palette, R: number, G: number, B: number, A: number?) -> (),
	Peek: (self: Palette, Index: number) -> (number, number, number, number),
	Iter: (self: Palette) -> () -> (number, number, number, number, number),
	__len: (self: Palette) -> number,
	Sort: (self: Palette) -> (),
}

export type Palette = typeof(setmetatable({} :: {
	Calcuator: DistanceCalcuator,
	Uint32Indexs: {number},
	Colors: {buffer},
	Size: number,
}, {} :: PalettePrototype))

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

type DistanceCalcuator = {
	CalcuateNormalized: CalcuatorFunction,
    Defualts: DistanceFormulaDefaults,
    CalculateRaw: CalcuatorFunction,
    WhitepointR: number,
    WhitepointG: number,
    WhitepointB: number,
    WhitepointA: number,
}

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

local BitConversionHex = 0xFFFFFFFF
local Uint32Hex = 0xFF
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

local function RGBAToUint32(R: number, G: number, B: number, A: number)
	return bit32.rshift(
		bit32.bor(bit32.lshift(A, 24), bit32.lshift(B, 16), bit32.lshift(G, 8), R), 0
	)
end

local function Uint32ToRGBA(Uint32: number)
	return bit32.band(Uint32, Uint32Hex), 
		bit32.band(bit32.rshift(Uint32, 8), Uint32Hex),
		bit32.band(bit32.rshift(Uint32, 16), Uint32Hex), 
		bit32.band(bit32.rshift(Uint32, 24), Uint32Hex)
end

local function RGBToHSL(R: number, G: number, B: number)
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

local function HueGroup(Hue: number, Segments: number)
	local LoopSegments = 360 / Segments
	local Half = LoopSegments / 2
	local Mid = LoopSegments - Half

	for Index = 1, LoopSegments do
		if Hue >= Mid and Hue < (Mid + LoopSegments) then 
			return Index
		end
		Mid += LoopSegments
	end
	return 0
end

local function To32Bit(N: number)
	return bit32.band(N, BitConversionHex)
end

--------------------------------------------------------------------------------
-- Buffer
--------------------------------------------------------------------------------

local function BufferReadRGBA(Buffer: buffer, Index: number?)
	local NewIndex = Index or 0
	return buffer.readu8(Buffer, NewIndex),
		buffer.readu8(Buffer, NewIndex + 1),
		buffer.readu8(Buffer, NewIndex + 2),
		buffer.readu8(Buffer, NewIndex + 3)
end

local function BufferReadUint32(Buffer: buffer)
	return buffer.readu32(Buffer, 4)
end

local function WriteOrCreateColorBuffer(
	R: number,
	G: number,
	B: number,
	A: number,
	ColorBuffer: buffer?
)
	local Buffer = ColorBuffer or buffer.create(8)
	buffer.writeu8(Buffer, 0, R)
	buffer.writeu8(Buffer, 1, G)
	buffer.writeu8(Buffer, 2, B)
	buffer.writeu8(Buffer, 3, A)
	buffer.writeu32(Buffer, 4, RGBAToUint32(R, G, B, A))
	return Buffer
end

local function BufferWriteRGBA(
	Buffer: buffer,
	Index: number,
	R: number,
	G: number,
	B: number,
	A: number
)
	local NewIndex = if Index > 1 then Index * 4 else 0
	buffer.writeu8(Buffer, NewIndex, R)
	buffer.writeu8(Buffer, NewIndex + 1, G)
	buffer.writeu8(Buffer, NewIndex + 2, B)
	buffer.writeu8(Buffer, NewIndex + 3, A)
	return Buffer
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
    A2: number
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
    A2: number
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

local function Calcuator_CalcuateNormalized(
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

local CalcuatorPrototype = {
	CalcuateNormalized = Calcuator_CalcuateNormalized
}
CalcuatorPrototype.__index = CalcuatorPrototype

local function CreateCalcuator(
    DistanceFormula: DistanceFormula,
    R: number?,
    G: number?,
    B: number?,
    A: number?
)
    local Calcuator = Calcuators[DistanceFormula]
    if not Calcuator then
        error(`[Quack] No distance calcuator exists for {DistanceFormula}`)
    end
	local R = R or 255
	local G = G or 255
	local B = B or 255
	local A = A or 255

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
-- Palette
--------------------------------------------------------------------------------

local HueGroups = 10

local function GetNearestIndex(
	Palette: Palette,
	R: number,
	G: number,
	B: number,
	A: number
)
	local Uint32 = RGBAToUint32(R, G, B, A)
	local CacheIndex = Palette.Uint32Indexs[Uint32]
	if CacheIndex then 
		return CacheIndex, R, G, B, A
	end
	
	local ClosestDistance = math.huge
	local ClosestIndex
	local ClosestR = 0
	local ClosestG = 0
	local ClosestB = 0
	local ClosestA = 0

	for _, ColorBuffer in self.Colors do
		local IndexR, IndexG, IndexB, IndexA = BufferReadRGBA(ColorBuffer)
		local Distance = Palette.Calculator:CalculateRaw(
			R, G, B, A, IndexR, IndexG, IndexB, IndexA
		)

		if Distance < ClosestDistance then
			ClosestDistance = Distance
			ClosestIndex = Index
			ClosestR = IndexR
			ClosestG = IndexG
			ClosestB = IndexB
			ClosestA = IndexA
		end
	end

	Palette.Uint32Indexs[Uint32] = ClosestIndex
	return ClosestIndex, ClosestR, ClosestG, ClosestB, ClosestA
end

local function GetNearestColor(
	Palette: Palette,
	R: number,
	G: number,
	B: number,
	A: number
): (number, number, number, number)
	return select(2, GetNearestIndex(Palette, R, G, B, A))
end

local function Palette_Remove(self: Palette, ValueOrIndex: any, G: number?, B: number?, A: number?)
	local Index = if ValueOrIndex and (not G and B and A) then
			ValueOrIndex :: number
		else
			GetNearestIndex(self, GetRGBA(ValueOrIndex, G, B, A))

	if Index > 0 then
		self.Uint32Indexs[BufferReadUint32(self.Colors[ValueOrIndex])] = nil
		local ColorBuffer = table.remove(self.Colors, Index)

		if ColorBuffer then
			self.Colors -= 1
		end
	end
end

local function Palette_Contains(self: Palette, Value: any, G: number?, B: number?, A: number?)
	local Uint32 = RGBAToUint32(GetRGBA(Value, G, B, A))

	for _, ColorBuffer in self.Colors do
		if BufferReadUint32(ColorBuffer) == Uint32 then 
			return true
		end
	end
	return false
end

local function Palette_Peek(self: Palette, Index: number?): (number?, number?, number?, number?)
	local ColorBuffer = self.Colors[Index or 1]

	if ColorBuffer then
		return BufferReadRGBA(ColorBuffer)
	else
		return nil, nil, nil, nil
	end
end

local function Palette_Nearest(self: Palette, Value: any, G: number?, B: number?, A: number?)
	local NewR, NewG, NewB, NewA, RGBAType = GetRGBA(Value, G, B, A)
	return FormatRGBA(RGBAType, GetNearestColor(self, NewR, NewG, NewB, NewA))
end

local function Palette_Add(self: Palette, Value: any, G: number?, B: number?, A: number?)
	local NewR, NewG, NewB, NewA = GetRGBA(Value, G, B, A)
	table.insert(self.Colors, WriteOrCreateColorBuffer(NewR, NewG, NewB, NewA))
	self.Size += 1
end

local function Palette_Iter(self: Palette)
	local Length = #self.Colors
	local Index = 1

	return function()
		Index = if Index ~= 1 then Index + 1 else Index

		if Index > Length then
			error("[Quack] Palette iterator tried to go out of bounds")
		end

		-- Index, R, G, B, A
		return Index, BufferReadRGBA(self.Colors[Index])
	end
end

-- TODO: group very low lum and very high lum colors
-- TODO: pass custom sort order
-- TODO: sort criteria function should be placed to HueStats class
-- note: > 0 is basically how you convert js sort to lua easily
-- its what robloxs luau polyfill does for its array.sort
local function Palette_Sort(self: Palette)
	table.clear(self.Uint32Indexs)

	table.sort(self.Colors, function(A, B)
		local AR, AG, AB, AA = BufferReadRGBA(A)
		local BR, BG, BB, BA = BufferReadRGBA(B)
		local AH, AS, AL = RGBToHSL(AR, AG, AB)
		local BH, BS, BL = RGBToHSL(BR, BG, BB)
	
		-- sort all grays + whites together
		local HueA = if AR == AG and AG == AB then 0 else 1 + HueGroup(AH, HueGroups)
		local HueB = if BR == BG and BG == BB then 0 else 1 + HueGroup(BH, HueGroups)
		local HueDiff = HueB - HueA
	
		if HueDiff > 0 then return -HueDiff > 0 end
		local LumA = GetRGBALuminosity(AR, AG, AB, AA)
		local LumB = GetRGBALuminosity(BR, BG, BB, BA)
		local LumDiff = LumB - LumA

		if LumDiff ~= 0 then return LumDiff > 0 end
		local ASat = AS * 100
		local BSat = BS * 100
		local SatDiff = (if BSat > 0 then BSat else 0) - (if ASat > 0 then ASat else 0)

		if SatDiff > 0 then
			return -SatDiff > 0
		else
			return false
		end
	end)
end

local PalettePrototype = {
	Contains = Palette_Contains,
	Nearest = Palette_Nearest,
	Remove = Palette_Remove,
	__len = GetClassLength,
	__iter = Palette_Iter,
	Iter = Palette_Iter,
	Sort = Palette_Sort,
	Peek = Palette_Peek,
	Add = Palette_Add,
}
PalettePrototype.__index = PalettePrototype

local function CreatePalette(Options: PaletteInfo): Palette
	return setmetatable({
		Colors = if Options.MaxColors then table.create(Options.MaxColors) else {},		
		Calculator = CreateCalcuator(
			Options.DistanceFormula or "ManhattanBT709", 
			Options.R, Options.G, Options.B, Options.A
		),
		Uint32Indexs = {},
		Size = 0,
	}, PalettePrototype) :: any
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
	Calcuator: DistanceCalcuator,
	ImageData: ImageData,
	Palette: Palette,
	DitheringMethod: DitheringMethod,
	Serpentine: boolean?,
	MinimumColorDistanceToDither: number?,
	CalculateErrorLikeGIMP: boolean?
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
		local XStart = if Dir == 1 then 0 else Width - 1
		local XEnd = if Dir == 1 then Width else -1

		-- cyclic shift with erasing
		FillErrorLine(ErrorLines[1], Width)
		table.insert(ErrorLines, table.remove(ErrorLines, 1) :: any)
		local Index = (Y * Width) + XStart
		local ErrorLine = ErrorLines[1]

		for X = XStart, XEnd, Dir do
			-- Image pixel
			local ColorBuffer = ImageData.Pixels[Index]
			local R, G, B, A = BufferReadRGBA(ColorBuffer)
			local Error = ErrorLine[X]

			local CorrectedR = math.clamp(R + Error[1], 0, 255)
			local CorrectedG = math.clamp(G + Error[2], 0, 255)
			local CorrectedB = math.clamp(B + Error[3], 0, 255)
			local CorrectedA = math.clamp(A + Error[4], 0, 255)

			-- Reduced pixel
			local PaletteR, PaletteG, PaletteB, PaletteA = GetNearestColor(
				Palette, CorrectedR, CorrectedG, CorrectedB, CorrectedA
			)

			ImageData.Pixels[Index] = WriteOrCreateColorBuffer(
				PaletteR, PaletteG, PaletteB, PaletteA, ColorBuffer
			)

			-- dithering strength
			if MinimumColorDistanceToDither then 
				local Distance = Calcuator:CalcuateNormalized(
					R, G, B, A, PaletteR, PaletteG, PaletteB, PaletteA
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

			local DStart = if Dir == 1 then 0 else #Kernels
			local DEnd = if Dir == 1 then #Kernels else 0

			for Index2 = DStart, DEnd, Dir do
				local X1 = Kernels[Index2][2] * Dir
				local Y1 = Kernels[Index2][3]
	  
				if 
					X1 + X >= 0 and X1 + X < Width and
					Y1 + Y >= 0 and Y1 + Y < Height
				then
					local E = ErrorLines[Y1][X1 + X]
					local D = Kernels[Index2][1]
					
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

local function HilbertCurve_Visit(self: HilbertCurve, Direction: number)
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

local HilbertCurvePrototype = {
	Walk = function(self: HilbertCurve, Direction: number)
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
	Visit = HilbertCurve_Visit,
}
HilbertCurvePrototype.__index = HilbertCurvePrototype

local function Dither_ErrorDiffusionRiemersma(
	DistanceCalcuator: DistanceCalcuator,
	ImageData: ImageData,
	Palette: Palette,
	ErrorPropagation: number?,
	ErrorQueueSize: number?
)
	local ErrorPropagation = ErrorPropagation or 1	
	local ErrorQueueSize = ErrorQueueSize or 16

	local Multiplier = math.exp(math.log(ErrorQueueSize) / (ErrorQueueSize - 1))
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
			local PixelIndex = (X + Y) * Width
			local ColorBuffer = ImageData.Pixels[PixelIndex]
			local R, G, B, A = BufferReadRGBA(ColorBuffer)
	
			for Index, Weight in Weights do
				local Error = ErrorQueue[(Index + Head) % ErrorQueueSize]
	
				R += Error[1] * Weight
				G += Error[2] * Weight
				B += Error[3] * Weight
				A += Error[4] * Weight
			end
			-- QuantizedPoint
			local QuantizedR, QuantizedG, QuantizedB, QuantizedA = GetNearestColor(
				Palette, math.clamp(R, 0, 255), math.clamp(G, 0, 255), math.clamp(B, 0, 255), 
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
			ImageData.Pixels[PixelIndex] = WriteOrCreateColorBuffer(
				QuantizedR, QuantizedG, QuantizedB, QuantizedA, ColorBuffer
			)
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
	Palette: Palette
)
	for Y = 1, ImageData.Height do
		local Index = Y * ImageData.Width

		for X = 1, ImageData.Width do
			-- Image pixel
			local ColorBuffer = ImageData.Pixels[Index]

			-- Reduced pixel
			ImageData.Pixels[Index] = WriteOrCreateColorBuffer(
				GetNearestColor(Palette, BufferReadRGBA(ColorBuffer)), ColorBuffer
			)
			Index += 1
		end
	end
end

--------------------------------------------------------------------------------
-- Hue Statistics
--------------------------------------------------------------------------------

--[[
 * @preserve
 * Copyright 2015-2018 Igor Bezkrovnyi
 * All rights reserved. (MIT Licensed)
 *
 * hueStatistics.ts - part of Image Quantization Library
--]]

local function CheckHueStatistics(HueStatistics: HueStatistics, Uint32: number)
	--[[
		if (this._groupsFull === this._numGroups + 1) {
			this.check = () => {};
	  	}
	--]]
	if HueStatistics.GroupsFull == HueStatistics.GroupAmount then return end

	local R = bit32.band(Uint32, 0xff)
	local G = bit32.band(bit32.rshift(Uint32, 8), 0xff)
	local B = bit32.band(bit32.rshift(Uint32, 16), 0xff)
	local H = RGBToHSL(R, G, B)
	local HG = if R == G and G == B then
			0
		else
			1 + HueGroup(H, HueStatistics.GroupAmount)
	local Min = HueStatistics.MinColors
	local GR = HueStatistics.Stats[HG]

	GR.Amount += 1

	if GR.Amount > HueStatistics.MinColors then
		return
	elseif GR.Amount == HueStatistics.MinColors then
		HueStatistics.GroupsFull += 1
	end
	if GR.Amount <= HueStatistics.MinColors then
		table.insert(GR.Colors, Uint32)
	end
end	

local function CreateHueStatistics(GroupAmount: number, MinColors: number)
	local Stats = table.create(GroupAmount) :: {HueGroup}

	for Index = 1, GroupAmount do
		Stats[Index] = {
			Colors = {},
			Amount = 0,
		}
	end

	return {
		GroupAmount = GroupAmount,
		MinColors = MinColors,
		GroupsFull = 0,
		Stats = Stats,
	}
end

--------------------------------------------------------------------------------
-- Histogram
--------------------------------------------------------------------------------

--[[
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
 --]]

local DefualtBoxSizeX = 64
local DefualtBoxSizeY = 64
local DefualtBoxPixels = 2
 
local function GetImportanceSortedColorsUint32(
	Histogram: {number},
	HueStats: HueStatistics,
	InitColors: number,
	IsGlobalPopulation: boolean
)
	local Keys = {}

	for Key in Histogram do
		table.insert(Keys, Key)
	end
	if #Keys == 0 then
		error("[Quack] No colors inside histogram")
	end

	table.sort(Keys, function(A, B)
		return (Histogram[B] - Histogram[A]) > 0
	end)

	local Uint32Indexs = if IsGlobalPopulation then table.clone(Keys) else Keys

	if IsGlobalPopulation then
		local InitialColorsLimit = math.min(#Keys, InitColors)
		-- this is just so that its an actual index, as js arrays start at 0
		-- and #keys == arrat.length in js, so without subtracting 1 it wouldnt
		-- be an actual index within the array
		-- const last = Keys[initialColorsLimit - 1]
		local Freq = Histogram[Keys[InitialColorsLimit]]
	
		-- add any cut off colors with same freq as last
		local Position = InitialColorsLimit
		let pos = initialColorsLimit;
		const len = sorted.length;

		while Position < #Keys and Histogram[Sorted[Position]] == Freq do
			Position += 1
			table.insert(Uint32Indexs, Keys[Position])
		end
	
		-- inject min huegroup colors
		for Index, Stat in HueStats.Stats do
			if Stat.Amount <= HueStats.MinColors then
				for _, ColorUint32 in Stat.Colors do
					if not table.find(Uint32Indexs, ColorUint32) then
						table.insert(Uint32Indexs, ColorUint32)
					end
				end
			end
		end
	end

	for Index, Value in Uint32Indexs do
		Uint32Indexs[Index] = To32Bit(Value)
	end
	return Uint32Indexs
end

-- partitions a rectangle of width x height into an array of boxes stepX x stepY (or less)
local function MakeBoxes(Width: number, Height: number, StepX: number, StepY: number)
	local wrem = width % stepX
	local hrem = height % stepY
	local xend = width - wrem
	local yend = height - hrem
	local Boxes = table.create(Height * Width)

	local BoxHeight = BoundingBox[4]
	local BoxWidth = BoundingBox[3]
	for Y = 0, Height, StepY do
		for X = 0, Width, StepX do
			local Box = table.create(4)
			Box[1] = X
			Box[2] = y
			Box[3] = if X == xend then wrem else StepX
			Box[4] = if Y == yend then hrem else StepY
			Boxes[#Boxes + 1] = Box
		end
	end
	return Boxes
end

-- population threshold within subregions
-- FIXME: this can over-reduce (few/no colors same?), need a way to keep
-- important colors that dont ever reach local thresholds (gradients?)
local function ColorStats2D(
	ImageData: ImageData,
	Histogram: {number},
	HueStats: HueStatistics,
	BoxPixels: number,
	BoxWidth: number,
	BoxHeight: number
)
	local Boxes = MakeBoxes(ImageData.Width, ImageData.Height, BoxWidth, BoxHeight)
	local Area = BoxWidth * BoxHeight

	for _, Box in Boxes do
		local Height = Box[4]
		local Width = Box[3]
		local PreEffc = math.floor((Width * Height) / Area) * BoxPixels
		local Effc = if PreEffc < 2 then 2 else PreEffc
		local Histogram2 = {} :: {number}
		local X = Box[1]
		local Y = Box[2]
	
		-- iterates @bbox within a parent rect of width @wid; calls @fn, passing index within parent
		local Max = (((Y + Height) - 1) * ImageData.Width) + ((X + Width) - 1)
		local Increment = (ImageData.Width - Width) + 1
		local Index = (Y * Width) + X
		local Count = 0
	
		while Index <= Max do
			local Uint32 = RGBAToUint32(ImageData:Peek(Index))

			-- collect hue stats
			CheckHueStatistics(HueStats, Uint32)

			if Histogram[Uint32] then
				Histogram[Uint32] += 1
			elseif Histogram2[Uint32] then
				Histogram2[Uint32] += 1
				local Value = Histogram2[Uint32]

				if Value >= Effc then
					Histogram[Uint32] = Value
				end
			else
				Histogram2[Uint32] = 1
			end

			Count += 1
			Index += if Count % Width == 0 then Increment else 1
		end
	end

	-- inject min huegroup colors
	for Index, Stat in HueStats do
		if Stat.Amount <= HueStats.MinColors then
			for _, ColorUint32 in Stat.Colors do
				if not Histogram[ColorUint32] then
					Histogram[ColorUint32] = 1
				else
					Histogram[ColorUint32] += 1
				end
			end
		end
	end
end

-- global top-population
local function ColorStats1D(ImageData: ImageData, Histogram: {number}, HueStats: HueStatistics)
	for _, R, G, B, A in ImageData do
		local Uint32 = RGBAToUint32(R, G, B, A)

		CheckHueStatistics(HueStats, Uint32)

		if Histogram[Uint32] then
			Histogram[Uint32] += 1
		else
			Histogram[Uint32] = 1
		end
	end
end

--------------------------------------------------------------------------------
-- Quantization
--------------------------------------------------------------------------------

local DefualtDistanceIncrement = 0.005
local DefualtInitalDistance = 0.01
local HueGroups = 10

local function BuildPalette(
	ImageOrImages: ImageData | {ImageData},
	Calculator: DistanceCalcuator,
	Method: Method,
	MaxColors: number,
	DistanceIncrement: number?,
	InitalDistance: number?
)
	-- subsequent passes threshold
	local DistanceIncrement = DistanceIncrement or DefualtDistanceIncrement
	-- color-distance threshold for initial reduction pass
	local InitalDistance = InitalDistance or DefualtInitalDistance
	local IsGlobalPopulation = Method == "GlobalPopulation"
	-- # of highest-frequency colors to start with for palette reduction
	local InitalColors = bit32.lshift(MaxColors, 2)
	-- if > 0, enables hues stats and min-color retention per group
	local MinHueColors = InitalColors
	-- accumulated histogram
	local Histogram = {} :: {number}

	local HueStats = CreateHueStatistics(HueGroups, MinHueColors)

	-- gathers histogram info
	if IsGlobalPopulation then
		local BoxHeight = 64
		local BoxWidth = 64
		local BoxPixels = 2

		if IsArray(ImagesOrImages) then
			for _, ImageData in ImagesOrImages then
				ColorStats2D(
					ImageData, Histogram, HueStats, BoxPixels, BoxWidth, BoxHeight
				)
			end
		else
			ColorStats2D(
				ImagesOrImages, Histogram, HueStats, BoxPixels, BoxWidth, BoxHeight
			)
		end
	else
		if IsArray(ImagesOrImages) then
			for _, ImageData in ImagesOrImages then
				ColorStats1D(ImageData, Histogram, HueStats)
			end
		else
			ColorStats1D(ImagesOrImages, Histogram, HueStats)
		end
	end
  
	-- reduces histogram to palette, remaps & memoizes reduced colors
	local Uint32Indexs = GetImportanceSortedColorsUint32(
		Histogram, HueStats, InitalColors, IsGlobalPopulation
	)
  
	-- reduces similar colors from an importance-sorted Uint32 rgba array
	-- reduce histogram to create initial palette
	-- build full rgb palette
	local Usage = table.create(#Uint32Indexs, true) :: {boolean}
	local Colors = {} :: {buffer}

	for Index, Uint32 in Uint32Indexs do
		table.insert(Colors, WriteOrCreateColorBuffer(Uint32ToRGBA(Uint32)))
	end

	local PaletteLength = #Colors
	local THold = InitalDistance
	local MemDist = {}

	while PaletteLength > MaxColors do
		table.clear(MemDist)

		-- iterate palette
		for Index, IsUsed in Usage do
			if IsUsed == false then continue end
			local Buffer = Colors[Index]

			for Index2 = Index + 1, #Usage do
				local IsUsed2 = Usage[Index2]
				if IsUsed2 == false then continue end
				local Buffer2 = Colors[Index2]

				local Distance = Calculator:CalcuateNormalized(
					BufferReadRGBA(Buffer),
					BufferReadRGBA(Buffer2)
				)

				if Distance < THold then
					local RemovedColor = table.create(3)
					RemovedColor[1] = Index2
					RemovedColor[2] = Buffer2
					RemovedColor[3] = Distance

					MemDist[#MemDist + 1] = RemovedColor
					Usage[Index2] = false
					PaletteLength -= 1
				end
			end
		end
		-- palette reduction pass
		-- console.log("palette length: " + palLen);
  
		-- if palette is still much larger than target, increment by larger initDist
		THold += if PaletteLength > MaxColors * 3 then InitalDistance else DistanceIncrement
	end
  
	-- if palette is over-reduced, re-add removed colors with largest distances from last round
	if PaletteLength < MaxColors then
		-- sort descending
		table.sort(MemDist, function(A, B)
			return (B[3] - A[3]) > 0
		end)

		for _, RemovedColor in MemDist do
			if PaletteLength > MaxColors then break end
			-- re-inject rgb into final palette
			Usage[RemovedColor[1]] = true
			PaletteLength += 1
		end
	end

	local ColorLength = #Colors
	--let colors = colorArray.length;
	for Index = #Colors, #Colors, -1 do
		if Usage[Index] == false then
			if Index ~= ColorLength then
				Colors[Index] = Colors[ColorLength]
			end

			ColorLength -= 1
		end
	end

	--[[
	  for (let colorIndex = colors - 1; colorIndex >= 0; colorIndex--) {
		if (usageArray[colorIndex] === 0) {
		  if (colorIndex !== colors - 1) {
			colorArray[colorIndex] = colorArray[colors - 1];
		  }

		  --colors;
		}
	  }
	  colorArray.length = colors;
	--]]
	local NewColors = table.create(ColorLength)
	table.move(Colors, 1, ColorLength, 1, NewColors)

	local Palette: Palette = setmetatable({
		Calculator = Calculator,
		Colors = NewColors,
		Size = ColorLength,
		Uint32Indexs = {},
	}, PalettePrototype) :: any

	Palette:Sort()
	return Palette
end

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

local function GetImageDatasFromImageOrImages(ImageOrImages: ImageOrImages)
	if IsArray(ImagesOrImages) then
		if typeof(ImagesOrImages[1]) == "Instance" then
			for Index, EditableImage in ImagesOrImages do
				ImagesOrImages[Index] = CreateImageData(EditableImage)
			end
		end
	elseif typeof(ImageOrImages) == "Instance" then
		return CreateImageData(ImagesOrImages)
	end
	return ImageOrImages
end

local function Dither(
	DitheringMethod: DitheringMethod,
	ImageOrImages: ImageOrImages,
	Palette: Palette, 
	Info: DitheringInfo
)
	local ImageOrImages = GetImageDatasFromImageOrImages(ImageOrImages)

	if IsArray(ImageOrImages) then
		if DitheringMethod == "ErrorDiffusionRiemersma" then
			for _, ImageData in ImageOrImages do
				Dither_ErrorDiffusionRiemersma(
					Palette.Calculator,
					ImageData,
					Palette,
					Info.ErrorPropagation,
					Info.ErrorQueueSize
				)
			end
		elseif DitheringMethod == "NearestColor" then
			for _, ImageData in ImageOrImages do
				Dither_NearestColor(Palette.Calculator, ImageData, Palette)
			end
		else
			for _, ImageData in ImageOrImages do
				Dither_ErrorDiffusionArray(
					Palette.Calculator,
					ImageData,
					Palette,
					DitheringMethod,
					Info.Serpentine,
					Info.MinimumColorDistanceToDither,
					Info.CalculateErrorLikeGIMP
				)
			end
		end
	else
		if DitheringMethod == "ErrorDiffusionRiemersma" then
			Dither_ErrorDiffusionRiemersma(
				Palette.Calculator,
				ImageOrImages,
				Palette,
				Info.ErrorPropagation,
				Info.ErrorQueueSize
			)
		elseif DitheringMethod == "NearestColor" then
			Dither_NearestColor(Palette.Calculator, ImageOrImages, Palette)
		else
			Dither_ErrorDiffusionArray(
				Palette.Calculator,
				ImageOrImages,
				Palette,
				DitheringMethod,
				Info.Serpentine,
				Info.MinimumColorDistanceToDither,
				Info.CalculateErrorLikeGIMP
			)
		end
	end
	return ImageOrImages
end

local function Palletize(ImageOrImages: ImageOrImages, Info: PalletizeInfo)
	local ImageOrImages = GetImageDatasFromImageOrImages(ImageOrImages)
	local Calculator = CreateCalcuator(
		Info.DistanceFormula or "ManhattanBT709", Info.R, Info.G, Info.B, Info.A
	)

	return BuildPalette(
		ImageOrImages, Calculator, Info.Method or "GlobalPopulation", 
		Info.MaxColors or 256, Info.DistanceIncrement, Info.InitalDistance
	)
end

local function Quantize(ImageOrImages: ImageOrImages, Info: QuantizeInfo)
	local ImageOrImages = GetImageDatasFromImageOrImages(ImageOrImages)
	local Calculator = CreateCalcuator(
		Info.DistanceFormula or "ManhattanBT709", Info.R, Info.G, Info.B, Info.A
	)

	local Palette = BuildPalette(
		ImageOrImages, Calculator, Info.Method or "GlobalPopulation",
		Info.MaxColors or 256, Info.DistanceIncrement, Info.InitalDistance
	)

	return Palette, Dither(
		Info.DitheringMethod or "NearestColor",
		ImageOrImages,
		Palette, 
		Info
	)
end

local function PalletizeAsync(ImageOrImages: ImageOrImages, Info: PalletizeInfo)
	return Future.Try(Palletize, ImageOrImages, Info)
end

local function QuantizeAsync(ImageOrImages: ImageOrImages, Info: QuantizeInfo)
	return Future.Try(Quantize, ImageOrImages, Info)
end

local function DitherAsync(
	DitheringMethod: DitheringMethod,
	ImageOrImages: ImageOrImages,
	Palette: Palette, 
	Info: DitheringInfo
)
	return Future.Try(Dither, DitheringMethod, ImageOrImages, Palette, Info)
end

local Exports = table.freeze({
	DitherAsync = DitherAsync :: ((DitheringMethod: "NearestColor", Image: ImageData | EditableImage, Palette: Palette) -> Future.Future<boolean, ImageData>) &
		((DitheringMethod: "NearestColor", Images: {ImageData}, Palette: Palette) -> Future.Future<boolean, {ImageData}>) &
		((DitheringMethod: "NearestColor", EditableImage: EditableImage, Palette: Palette) -> Future.Future<boolean, ImageData>) &,
		((DitheringMethod: "NearestColor", EditableImages: {EditableImage}, Palette: Palette) -> Future.Future<boolean, {ImageData}>) &
		((DitheringMethod: ArrayDitheringMethod, Image: ImageData | EditableImage, Palette: Palette, ErrorDiffusionArrayInfo: ErrorDiffusionArrayInfo) -> Future.Future<boolean, ImageData>) &
		((DitheringMethod: ArrayDitheringMethod, Images: {ImageData}, Palette: Palette, ErrorDiffusionArrayInfo: ErrorDiffusionArrayInfo) -> Future.Future<boolean, {ImageData}>) &
		((DitheringMethod: ArrayDitheringMethod, EditableImage: EditableImage, Palette: Palette, ErrorDiffusionArrayInfo: ErrorDiffusionArrayInfo) -> Future.Future<boolean, ImageData>) &
		((DitheringMethod: ArrayDitheringMethod, EditableImages: {EditableImage}, Palette: Palette, ErrorDiffusionArrayInfo: ErrorDiffusionArrayInfo) -> Future.Future<boolean, {ImageData}>) &
		((DitheringMethod: "ErrorDiffusionRiemersma", Image: ImageData | EditableImage, Palette: Palette, ErrorDiffusionRiemersmaInfo: ErrorDiffusionRiemersmaInfo) -> Future.Future<boolean, ImageData>) &
		((DitheringMethod: "ErrorDiffusionRiemersma", Images: {ImageData}, Palette: Palette, ErrorDiffusionRiemersmaInfo: ErrorDiffusionRiemersmaInfo) -> Future.Future<boolean, {ImageData}>) &
		((DitheringMethod: "ErrorDiffusionRiemersma", EditableImage: EditableImage, Palette: Palette, ErrorDiffusionRiemersmaInfo: ErrorDiffusionRiemersmaInfo) -> Future.Future<boolean, ImageData>) &
		((DitheringMethod: "ErrorDiffusionRiemersma", EditableImages: {EditableImage}, Palette: Palette, ErrorDiffusionRiemersmaInfo: ErrorDiffusionRiemersmaInfo) -> Future.Future<boolean, {ImageData}>),

	Dither = Dither :: ((DitheringMethod: "NearestColor", Image: ImageData | EditableImage, Palette: Palette) -> ImageData) &
		((DitheringMethod: "NearestColor", Images: {ImageData}, Palette: Palette) -> {ImageData}) &
		((DitheringMethod: "NearestColor", EditableImage: EditableImage, Palette: Palette) -> ImageData) &,
		((DitheringMethod: "NearestColor", EditableImages: {EditableImage}, Palette: Palette) -> {ImageData}) &
		((DitheringMethod: ArrayDitheringMethod, Image: ImageData | EditableImage, Palette: Palette, ErrorDiffusionArrayInfo: ErrorDiffusionArrayInfo) -> ImageData) &
		((DitheringMethod: ArrayDitheringMethod, Images: {ImageData}, Palette: Palette, ErrorDiffusionArrayInfo: ErrorDiffusionArrayInfo) -> {ImageData}) &
		((DitheringMethod: ArrayDitheringMethod, EditableImage: EditableImage, Palette: Palette, ErrorDiffusionArrayInfo: ErrorDiffusionArrayInfo) -> ImageData) &
		((DitheringMethod: ArrayDitheringMethod, EditableImages: {EditableImage}, Palette: Palette, ErrorDiffusionArrayInfo: ErrorDiffusionArrayInfo) -> {ImageData}) &
		((DitheringMethod: "ErrorDiffusionRiemersma", Image: ImageData | EditableImage, Palette: Palette, ErrorDiffusionRiemersmaInfo: ErrorDiffusionRiemersmaInfo) -> ImageData) &
		((DitheringMethod: "ErrorDiffusionRiemersma", Images: {ImageData}, Palette: Palette, ErrorDiffusionRiemersmaInfo: ErrorDiffusionRiemersmaInfo) -> {ImageData}) &
		((DitheringMethod: "ErrorDiffusionRiemersma", EditableImage: EditableImage, Palette: Palette, ErrorDiffusionRiemersmaInfo: ErrorDiffusionRiemersmaInfo) -> ImageData) &
		((DitheringMethod: "ErrorDiffusionRiemersma", EditableImages: {EditableImage}, Palette: Palette, ErrorDiffusionRiemersmaInfo: ErrorDiffusionRiemersmaInfo) -> {ImageData}),	

	QuantizeAsync = QuantizeAsync :: ((Image: ImageData, PalletizeInfo: PalletizeInfo) -> Future.Future<boolean, Palette, ImageData>) &
		((Images: {ImageData}, PalletizeInfo: PalletizeInfo) -> Future.Future<boolean, Palette, {ImageData}>) &
		((EditableImage: EditableImage, PalletizeInfo: PalletizeInfo) -> Future.Future<boolean, Palette, ImageData>) &
		((EditableImages: {EditableImage}, PalletizeInfo: PalletizeInfo) -> Future.Future<boolean, Palette, {ImageData}>),

	ImageData = CreateImageData :: ((Pixels: {number}, Width: number, Height: number, CopyPixels: boolean?) -> ImageData<{number}>) &
		((Pixels: buffer, Width: number, Height: number, CopyPixels: boolean?) -> ImageData<buffer>) &
		((EditableImage: EditableImage) -> ImageData<{number}>),

	PalletizeAsync = PalletizeAsync :: ((Image: ImageData, PalletizeInfo: PalletizeInfo) -> Future.Future<boolean, Palette>) &
		((Images: {ImageData}, PalletizeInfo: PalletizeInfo) -> Future.Future<boolean, Palette>) &
		((EditableImage: EditableImage, PalletizeInfo: PalletizeInfo) -> Future.Future<boolean, Palette>) &
		((EditableImages: {EditableImage}, PalletizeInfo: PalletizeInfo) -> Future.Future<boolean, Palette>),

	Quantize = Quantize:: ((Image: ImageData, PalletizeInfo: PalletizeInfo) -> (Palette, ImageData)) &
		((Images: {ImageData}, PalletizeInfo: PalletizeInfo) -> (Palette, {ImageData})) &
		((EditableImage: EditableImage, PalletizeInfo: PalletizeInfo) -> (Palette, ImageData)) &
		((EditableImages: {EditableImage}, PalletizeInfo: PalletizeInfo) -> (Palette, {ImageData})),

	Palettize = Palletize :: (<T>(Image: ImageData<T>, PalletizeInfo: PalletizeInfo) -> Palette) &
		(<T>(Images: {ImageData<T>}, PalletizeInfo: PalletizeInfo) -> Palette) &
		((EditableImage: EditableImage, PalletizeInfo: PalletizeInfo) -> Palette) &
		((EditableImages: {EditableImage}, PalletizeInfo: PalletizeInfo) -> Palette),

	Palette = CreatePalette,
})

return Exports