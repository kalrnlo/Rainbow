--!optimize 2
--!strict
--!native

-- Quack
-- A lightweight-ish color quantization library for luau
-- Based on image-quantization and RgbQuant
-- @Kalrnlo
-- 27/02/2024

local Distance = require(script.Parent.Distance)
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

type RGBAType = "buffer" | "table" | "Color3" | "number"

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

t
type PalettePrototype = {
	Nearest: (self: Palette, R: number, G: number, B: number, A: number?) -> (number, number, number, number),
	Contains: (self: Palette, R: number, G: number, B: number, A: number?) -> boolean,
	Remove: ((self: Palette, R: number, G: number, B: number, A: number?) -> ()) &
		((self: Palette, Index: number) -> ()),
	Peek: (self: Palette, Index: number) -> (number, number, number, number),
	Add: (self: Palette, R: number, G: number, B: number, A: number?) -> (),
	Iter: (self: Palette) -> () -> (number, number, number, number, number),
	Sort: (self: Palette) -> (),
	
	__iter: (self: Palette) -> () -> (number, number, number, number, number),
	__len: (self: Palette) -> number,
}

export type Palette = typeof(setmetatable({} :: {
	Calcuator: DistanceCalcuator,
	Uint32Indexs: {number},
	Colors: {buffer},
	Size: number,
}, {} :: PalettePrototype))

local u32ConversionHex = 0xFFFFFFFF
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