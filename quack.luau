--!optimize 2
--!strict
--!native

-- Quack
-- A lightweight-ish color quantization library for luau
-- Based on image-quantization and RgbQuant
-- @Kalrnlo
-- 27/02/2024

--[[
local Image = Quant.ImageData.new(EditableImage)

-- Palette class has an iterator like this aswell
for Index, R, G, B, A in Image1 do
	print(`Pixel({Index}) {R}, {G}, {B}, {A}`)
end

local ImageData = Quack.Dither("FloydSteinberg", Palette, {Image, Image2})
local ImageData = Quack.Dither("FloydSteinberg", Palette, Image)

local Palette, ImageData = Quack.QuantizeAsync(Image, {
	DitheringMethod = "FloydSteinberg",
	DistanceFormula = "Manhattan",
	Method = "GlobalPopulation",
	Colors = 256
}):Await()

local Palette, ImageData = Quack.Quantize(Image, {
	DitheringMethod = "FloydSteinberg",
	DistanceFormula = "Manhattan",
	Method = "GlobalPopulation",
	Colors = 256
})

local Palette = Quack.Palettize(Image, {
	DistanceFormula = "Manhattan",
	Colors = 256
})
--]]

local Future = require(script.Parent.Future)

type DitheringMethod = "FloydSteinberg" | "FalseFloydSteinberg" | "Stucki" | "Atkinson" |
	"Jarvis" | "Burkes" | "Sierra" | "TwoSierra" | "SierraLite" | 
	"ErrorDiffusionRiemersma" | "NearestColor"

type DistanceFormula = "Manhattan" | "Euclidean" | "ManhattanBT709" | "CMetric" |
	"ManhattanNommyde" | "EuclideanBT709" | "PNGQuant"

type Method = "GlobalPopulation" | "SubRegionPopulation"

type RGBAType = "buffer" | "table" | "Color3" | "number"

type PalletizeInfo = {
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

type HueStatistics = {
	InjectIntoDictionary: (self: HueStatistics, Histogram: {[number]: number}) -> (),
	InjectIntoArray: (self: HueStatistics, Histogram: {number}) -> (),
	Check: (self: HueStatistics, Uint32: number) -> (),
	GroupAmount: number,
	GroupsFull: number,
	MinColors: number,
	Stats: {HueGroup},
}

type PaletteInfo = {
	DistanceFormula: DistanceFormula?,
	Calculator: DistanceCalcuator?,
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

type ImageDataPrototype<T> = {
	Set: ((self: ImageData<T>, Index: number, R: number, G: number, B: number, A: number?) -> ()) &
		((self: ImageData<T>, Index: number,  Color3: Color3) -> ()) &
		((self: ImageData<T>, Index: number, RGBOrRGBA: {number}) -> ()) &
		((self: ImageData<T>, Index: number, RGBOrRGBA: buffer) -> ()),
	__iter: (self: ImageData<T>) -> () -> (number, number, number, number, number),
	Peek: (self: ImageData<T>, Index: number) -> (number, number, number, number),
	Iter: (self: ImageData<T>) -> () -> (number, number, number, number, number),
	__len: (self: ImageData<T>) -> number,
}

type PalettePrototype = {
	Nearest: ((self: Palette, R: number, G: number, B: number, A: number?) -> (number, number, number, number)) &
		((self: Palette, Color3: Color3) -> (Color3, number)) &
		((self: Palette, RGBOrRGBA: {number}) -> {number}) &
		((self: Palette, RGBOrRGBA: buffer) -> buffer),
	Contains: ((self: Palette, R: number, G: number, B: number, A: number?) -> boolean) &
		((self: Palette, Color3: Color3) -> boolean) &
		((self: Palette, RGBOrRGBA: {number}) -> boolean) &
		((self: Palette, RGBOrRGBA: buffer) -> boolean),
	Remove: ((self: Palette, R: number, G: number, B: number, A: number?) -> ()) &
		((self: Palette, Color3: Color3) -> ()) &
		((self: Palette, RGBOrRGBA: {number}) -> ()) &
		((self: Palette, RGBOrRGBA: buffer) -> ()) &
		((self: Palette, Index: number) -> ()),
	Add: ((self: Palette, R: number, G: number, B: number, A: number?) -> ()) &
		((self: Palette, Color3: Color3) -> ()) &
		((self: Palette, RGBOrRGBA: {number}) -> ()) &
		((self: Palette, RGBOrRGBA: buffer) -> ()),
	Peek: (self: Palette, Index: number) -> (number, number, number, number),
	Iter: (self: Palette) -> () -> (number, number, number, number, number),
	Sort: (self: Palette) -> (),
	
	__iter: (self: Palette) -> () -> (number, number, number, number, number),
	__len: (self: Palette) -> number,
}

type ImageData<T> = typeof(setmetatable({} :: {
	Pixels: T & ({number} | buffer),
	Height: number,
	Width: number,
	Size: number,
}, {} :: ImageDataPrototype<T>))

type Palette = typeof(setmetatable({} :: {
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

local 32BitConversionHex = 0xFFFFFFFF
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

local function FormatRGBA(RGBAType: RGBAType, R: number, G: number, B: number, A: number): any
	if RGBAType == "number" then
		return R, G, B, A
	elseif RGBAType == "Color3" then
		return Color3.fromRGB(R, G, B), A
	elseif RGBAType == "table" then
		local RGBATable = table.create(4)
		RGBATable[1] = R
		RGBATable[1] = G
		RGBATable[1] = B
		RGBATable[1] = A
		return RGBATable
	else
		local RGBABuffer = buffer.create(4)
		buffer.writeu8(RGBABuffer, 0, R)
		buffer.writeu8(RGBABuffer, 1, G)
		buffer.writeu8(RGBABuffer, 2, B)
		buffer.writeu8(RGBABuffer, 3, A)
		return RGBABuffer
	end
end

local function GetRGBA(
	Value: number | buffer | Color3 | {number},
	G: number?,
	B: number?,
	A: number?
): (number, number, number, number, RGBAType)
	if typeof(Value) == "number" and G and B and A then
		return R, G, B, A, typeof(Value)
	elseif typeof(Value) == "buffer" then
		-- ColorBuffers in Palette.Colors are 8 bytes
		-- so allowing it to be greater than 4 is so someone could
		-- use a ColorBuffer without it erroring
		if buffer.len(Value) >= 4 then
			return buffer.readu8(Value, 0), 
				buffer.readu8(Value, 1),
				buffer.readu8(Value, 2),
				buffer.readu8(Value, 3),
				typeof(Value)
		elseif buffer.len(Value) == 3 then
			return buffer.readu8(Value, 0), 
				buffer.readu8(Value, 1),
				buffer.readu8(Value, 2), 
				0,
				typeof(Value)
		else
			error("[Quack] buffer provided does not have length of either 3 or 4++")
		end
	elseif typeof(Value) == "Color3" then
		return math.clamp(math.ceil(Color3.R * 255), 0, 255),
			math.clamp(math.ceil(Color3.G * 255), 0, 255),
			math.clamp(math.ceil(Color3.B * 255), 0, 255),
			0,
			typeof(Value)
	elseif typeof(Value) == "table" then
		if #Value >= 3 then
			return Value[1],
				Value[2],
				Value[3],
				Value[4] or 0,
				typeof(Value)
		else
			error("[Quack] Table is not of valid lengths 3 or 4")
		end
	else
		error("[Quack] Value is not of types that represent an RGB or RGBA value:\n\t3 or 4 long array, Color3, 3 or 4 long tuple made up of numbers, or a 3 or 4++ long buffer with the first 3 or 4 bytes as u8s")
	end
end

local function GetClassLength<T>(self: T & {Size: number})
	return self.Size
end

local function To32Bit(N: number)
	return bit32.band(N, 32BitConversionHex)
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
-- Image Data
--------------------------------------------------------------------------------

local function ImageData_Peek<T>(self: ImageData<T>, Index: number): (number?, number?, number?, number?)
	if typeof(self.Pixels) == "table" then
		if Index < 1 then
			return nil, nil, nil, nil
		end
		local NewIndex = if Index > 1 then Index * 4 else 1

		return self.Pixels[NewIndex], self.Pixels[NewIndex + 1],
			self.Pixels[NewIndex + 2], self.Pixels[NewIndex + 3]
	else
		if Index < 0 then
			return nil, nil, nil, nil
		end
		local NewIndex = if Index > 1 then Index * 4 else 0

		if NewIndex > buffer.len(self.Pixels) then
			return nil, nil, nil, nil
		else
			return BufferReadRGBA(self.Pixels, Index)
		end
	end
end

local function ImageData_Iter<T>(self: ImageData<T>)
	if typeof(self.Pixels) == "table" then
		local Length = #self.Pixels
		local Index = 1

		return function()
			Index = if Index ~= 1 then Index + 4 else Index

			if Index > Length then
				error("[Quack] ImageData iterator tried to go out of bounds")
			end

			-- Index, R, G, B, A
			return Index, self.Pixels[Index], self.Pixels[Index + 1],
				self.Pixels[Index + 2], self.Pixels[Index + 3]
		end
	else
		local Length = buffer.len(self.Pixels)
		local Index = 0

		return function()
			Index = if Index ~= 0 then Index + 4 else Index
			
			if Index > Length then
				error("[Quack] ImageData iterator tried to go out of bounds")
			end

			-- Index, R, G, B, A
			return Index, BufferReadRGBA(self.Pixels, Index)
		end
	end
end

local function ImageData_Set<T>(
	self: ImageData<T>,
	Index: number,
	Value: any,
	G: number,
	B: number,
	A: number?
)
	local R, G, B, A = GetRGBA(Value, G, B, A)

	if typeof(self.Pixels) == "table" then
		if Index < 1 then return end
		local NewIndex = if Index > 1 then Index * 4 else 1

		self.Pixels[NewIndex] = R
		self.Pixels[NewIndex + 1] = G
		self.Pixels[NewIndex + 2] = B
		self.Pixels[NewIndex + 3] = A or 0
	else
		if Index < 0 then return end
		local NewIndex = if Index > 1 then Index * 4 else 0

		if NewIndex + 4 <= buffer.len(self.Pixels) then
			buffer.writeu8(self.Pixels, NewIndex, R)
			buffer.writeu8(self.Pixels, NewIndex + 1, G)
			buffer.writeu8(self.Pixels, NewIndex + 2, B)
			buffer.writeu8(self.Pixels, NewIndex + 3, A)
		end
	end
end

local ImageDataPrototype = {
	__iter = ImageData_Iter,
	__len = GetClassLength,
	Iter = ImageData_Iter,
	Peek = ImageData_Peek,
	Set = ImageData_Set,
}
ImageDataPrototype.__index = ImageDataPrototype

local function CreateImageData(Data: EditableImage | {number} | buffer, Width: number?, Height: number?, CopyPixels: boolean?)
	if typeof(Data) == "Instance" then
		return setmetatable({
			Pixels = Data:ReadPixels(Vector2.new(), Data.Size),
			Height = Data.Size.Y,
			Width = Data.Size.X,
		}, ImageDataPrototype)
	else
		local Length = if typeof(Data) == "table" then #Data else buffer.len(Data)

		if not Width or Height then
			error("[Quack] Cannot create ImageData for array or buffer, without Width or Height provided")
		elseif Length < 4 then
			error("[Quack] Data provided does not include atleast 1 pixel")
		end
		local CopyPixels = CopyPixels or true
		local Pixels = Data

		if CopyPixels then
			if typeof(Data) == "buffer" then
				Pixels = buffer.create(Length)
				buffer.copy(Pixels, 0, Data)
			else
				Pixels = table.clone(Data)
			end
		end

		return setmetatable({
			Size = Length / 4,
			Pixels = Pixels,
			Height = Height,
			Width = Width,
		}, ImageDataPrototype)
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

		if LumDiff ~= 0 then return LumDiff > 0
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

			local DStart = if Dir == 1 then 0 else #Kernels - 1
			local DEnd = if Dir == 1 then #Kernels else -1

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

-- bad attempt at making it clear its a dictionary using {[number]: number}, but eh
local function HueStatistics_InjectIntoDictionary(self: HueStatistics, Histogram: {[number]: number})
	for Index, Stat in self.Stats do
		if Stat.Amount <= self.MinColors then
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

local function HueStatistics_InjectIntoArray(self: HueStatistics, Histogram: {number})
	for Index, Stat in self.Stats do
		if Stat.Amount <= self.MinColors then
			for _, ColorUint32 in Stat.Colors do
				if not table.find(Histogram, Color) then
					table.insert(Histogram, Color)
				end
			end
		end
	end
end

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
	local HG = if R == G and G == b then
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

local HueStatistics = {
	InjectIntoDictionary = HueStatistics_InjectIntoDictionary,
	InjectIntoArray = HueStatistics_InjectIntoArray,
	Check = CheckHueStatistics,
}
HueStatistics.__index = HueStatistics

local function CreateHueStatistics(GroupAmount: number, MinColors: number)
	local Stats = table.create(GroupAmount) :: {HueGroup}

	for Index = 1, GroupAmount do
		Stats[Index] = {
			Colors = {},
			Amount = 0,
		}
	end

	return setmetatable({
		GroupAmount = GroupAmount,
		MinColors = MinColors,
		GroupsFull = 0,
		Stats = Stats,
	}, HueStatistics)
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
	Method: Method,
)
	local Keys = {}

	for Key in Histogram do
		table.insert(Keys, Key)
	end
	if #Keys == 0 then return {} end

	table.sort(Keys, function(A, B)
		return (Histogram[B] - Histogram[A]) > 0
	end)

	local IsGlobalPopulation = Method == "GlobalPopulation"
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

-- partitions a rectangle of width x height into an array of boxes stepX x stepY (or less)
local function MakeBoxes(Width: number, Height: number, StepX: number, StepY: number)
	local wrem = width % stepX;
	local hrem = height % stepY;
	local xend = width - wrem;
	local yend = height - hrem;
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
			CheckHueStatistics(HueStats)

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

local DistanceIncrement = 0.005
local InitalDistance = 0.01

local function Quantize(
	Calculator: DistanceCalcuator,
	Method: Method,
	Colors: number
)
	-- # of highest-frequency colors to start with for palette reduction
	local InitalColors = bit32.lshift(Colors, 2)
	-- if > 0, enables hues stats and min-color retention per group
	local MinHueCols = bit32.lshift(Colors, 2)


end

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

  -- reduces histogram to palette, remaps & memoizes reduced colors
  *quantize() {
    const idxi32 = this._histogram.getImportanceSortedColorsIDXI32();
    if (idxi32.length === 0) {
      throw new Error('No colors in image');
    }

    yield* this._buildPalette(idxi32);
  }

  -- reduces similar colors from an importance-sorted Uint32 rgba array
  private *_buildPalette(
    idxi32: number[],
  ): IterableIterator<PaletteQuantizerYieldValue> {
    -- reduce histogram to create initial palette
    -- build full rgb palette
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

    -- palette already at or below desired length
    while (palLen > this._colors) {
      memDist.length = 0;

      -- iterate palette
      for (let i = 0; i < len; i++) {
        if (usageArray[i] === 0) continue;
        const pxi = colorArray[i];
        -- if (!pxi) continue;

        for (let j = i + 1; j < len; j++) {
          if (usageArray[j] === 0) continue;
          const pxj = colorArray[j];
          -- if (!pxj) continue;

          const dist = this._distance.calculateNormalized(pxi, pxj);
          if (dist < thold) {
            -- store index,rgb,dist
            memDist.push(new RemovedColor(j, pxj, dist));
            usageArray[j] = 0;
            palLen--;
          }
        }
      }
	-- palette reduction pass
      -- console.log("palette length: " + palLen);

      -- if palette is still much larger than target, increment by larger initDist
      thold +=
        palLen > this._colors * 3
          ? this._initialDistance
          : this._distanceIncrement;
    }

    -- if palette is over-reduced, re-add removed colors with largest distances from last round
    if (palLen < this._colors) {
      -- sort descending
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

local Exports = table.freeze({
	ImageData = CreateImageData :: ((Pixels: {number}, Width: number, Height: number, CopyPixels: boolean?) -> ImageData<{number}>) &
		((Pixels: buffer, Width: number, Height: number, CopyPixels: boolean?) -> ImageData<buffer>) &
		((EditableImage: EditableImage) -> ImageData<{number}>),
	Palette = CreatePalette,
})

return Exports
