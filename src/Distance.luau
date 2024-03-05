--!optimize 2
--!strict
--!native

-- Distance
-- A lightweight-ish color quantization library for luau
-- Based on image-quantization and RgbQuant
-- @Kalrnlo
-- 27/02/2024

export type DistanceFormula = "Manhattan" | "Euclidean" | "ManhattanBT709" | "CMetric" |
	"ManhattanNommyde" | "EuclideanBT709" | "PNGQuant"

type DistanceFormulaDefaults = {
    KR: number,
    KG: number,
    KB: number,
    KA: number,   
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

export type DistanceCalcuator = {
	CalcuateNormalized: CalcuatorFunction,
    Defualts: DistanceFormulaDefaults,
    CalculateRaw: CalcuatorFunction,
	Whitepoint: {
		R: number,
		G: number,
		B: number,
		A: number,
	}
    WhitepointR: number,
    WhitepointG: number,
    WhitepointB: number,
    WhitepointA: number,
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
        error(`[Rainbow][Distance] No distance calcuator exists for {DistanceFormula}`)
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
