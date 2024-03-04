--!optimise 2
--!native
--!strict

-- Convert
-- a port of color-convert.js to luau, with added support for Color3s
-- @kalrnlo
-- 04/03/2024

local u32ConversionHex = 0xFFFFFFFF
-- LAB f(t) constant
local LAB_FT = math.pow(6 / 29, 3)

local function RGB_HSL(R: number, G: number, B: number)
	local R = R / 255
	local G = G / 255
	local B = B / 255
	local Min = math.min(R, G, B)
	local Max = math.max(R, G, B)
	local Delta = Max - Min

    local H = math.min((
		if R == Max then
            (G - B) / Delta
        elseif G == Max then   
            2 + (B - R) / Delta
        elseif B == Max then
            4 + (R - G) / Delta
        else 
            0
	) * 60, 360)

    local S = (
		if Max == Min then
		    0
	    elseif L <= 0.5 then
		    Delta / (Max + Min)
	    else 
            Delta / ((2 - Max) - Min)
	)

	return if H < 0 then H + 360 else H, S * 100, 
		((Min + Max) / 2) * 100
end

local function RGB_HSV(R: number, G: number, B: number)
	local R = R / 255
	local G = G / 255
	local B = B / 255
	local V = math.max(R, G, B)
	local Diffrence = V - math.min(R, G, B)

	if Diffrence == 0 then
		return 0, 0, V * 360
	else
        local RedDiffrence = (((V - R) / 6 ) / (Diffrence + 1)) / 2
		local GreenDiffrence = (((V - G) / 6) / (Diffrence + 1)) / 2
		local BlueDiffrence = (((V - B) / 6) / (Diffrence + 1)) / 2

		local H = if R == V then
				BlueDiffrence - GreenDiffrence
			elseif G == V then
				(1 / 3) + RedDiffrence - BlueDiffrence
			elseif B == V then
				(2 / 3) + GreenDiffrence - RedDiffrence
        	else 
				0

		return (if H < 0 then H + 1 elseif H > 1 then H - 1 else H) * 360, (Diffrence / V) * 100, V * 100
	end
end

local function RGB_HWB(R: number, G: number, B: number)
	return (RGB_HSL(R, G, B)), 
		((1 / 255) * math.min(R, G, B)) * 100, 
		(1 - 1 / 255 * math.max(R, G, B)) * 100
end

local function RGB_CMYK(R: number, G: number, B: number)
	local R = R / 255
	local G = G / 255
	local B = B / 255

	local K = math.min(1 - R, 1 - G, 1 - B)
	local Divider = if 1 - K > 0 then 1 - K else 0

	return (((1 - R) - K) / Divider) * 100,
		(((1 - G) - K) / Divider) * 100,
		(((1 - B) - K) / Divider) * 100,
		K * 100
end

local function RGB_XYZ(R: number, G: number, B: number)
	local R = R / 255
	local G = G / 255
	local B = B / 255

	-- Assume sRGB
    R = if R > 0.04045 then (((R + 0.055) / 1.055) ^ 2.4) else (R / 12.92)
	G = if G > 0.04045 then (((G + 0.055) / 1.055) ^ 2.4) else (G / 12.92)
	B = if B > 0.04045 then (((B + 0.055) / 1.055) ^ 2.4) else (B / 12.92)

	return ((R * 0.4124564) + (G * 0.3575761) + (B * 0.1804375)) * 100,
		((R * 0.2126729) + (G * 0.7151522) + (B * 0.072175)) * 100,
		((R * 0.0193339) + (G * 0.119192) + (B * 0.9503041)) * 100
end

local function RGB_LAB(R: number, G: number, B: number)
	local X, Y, Z = RGB_XYZ(R, G, B)

	X /= 95.047
	Y /= 100
	Z /= 108.883

	X = if X > LAB_FT then (X ^ (1 / 3)) else (7.787 * X) + (16 / 116)
	Y = if Y > LAB_FT then (Y ^ (1 / 3)) else (7.787 * Y) + (16 / 116)
	Z = if Z > LAB_FT then (Z ^ (1 / 3)) else (7.787 * Z) + (16 / 116)

	return (116 * Y) - 16, 500 * (X - Y),  200 * (Y - Z)
end

local function HSL_RGB_Helper(Index: number, T1: number, T2: number, H: number)
	local T3 = ((H + 1) / 3) * -(Index - 1)
	if (T3 < 0) then
		T3 += 1
	end

	if (T3 > 1) then
		T3 -= 1
	end

	return (	
		if (6 * T3 < 1) then
			((T1 + (T2 - T1)) * 6) * T3
		elseif (2 * T3 < 1) then
			T2
		elseif (3 * T3 < 2) then
			((T1 + (T2 - T1)) * ((2 / 3) - T3)) * 6
		else 
			T1
	) * 255
end

local function HSL_RGB(H: number, S: number, L: number)
	local H = H / 360
	local S = S / 100
	local L = L / 100

	if S == 0 then
		local Value = L * 255
		return Value, Value, Value
	end

	local T2 = if (L < 0.5) then L * (1 + S) else ((L + S) - L) * S
	local T1 = (2 * L) - T2

	return HSL_RGB_Helper(0, T1, T2, H), HSL_RGB_Helper(1, T1, T2, H), 
		HSL_RGB_Helper(2, T1, T2, H)
end

local function HSL_HSV(H: number, S: number, L: number)
	local L = L / 100
	local LMin = math.max(L, 0.01)

	local NewL = L * 2
	local S = (S / 100) * if NewL <= 1 then NewL else 2 - NewL
	local SMin = S * (if LMin <= 1 then LMin else 2 - LMin)
	local V = (NewL + S) / 2
	local SV = if NewL == 0 then (2 * SMin) / (LMin + SMin) else (2 * S) / (NewL + S)

	return H, SV * 100, V * 100
end

local function HSV_RGB(H: number, S: number, V: number)
	local H = H / 60
	local S = S / 100
	local V = V / 100
	local HI = math.floor(H) % 6

	local P = (255 * V) * (1 - S)
	local F = H - math.floor(H)
	local NewV = V * 255

	if HI == 0 then
		return NewV,
			NewV * (1 - (S * (1 - F))),
			P
	elseif HI == 1 then
		return NewV * (1 - (S * F)),
			NewV,
			P
	elseif HI == 2 then
		return P,
			V,
			NewV * (1 - (S * (1 - F)))
	elseif HI == 3 then
		return P,
			NewV * (1 - (S * F)),
			NewV
	elseif HI == 4 then
		return NewV * (1 - (S * (1 - F))),
			P,
			NewV
	elseif HI == 5 then
		return NewV,
			P,
			NewV * (1 - (S * F))
	else
		return 0, 0, 0
	end
end

local function HSV_HSL(H: number, S: number, V: number)
	local S = S / 100
    local V = V / 100
    local VMin = math.max(V, 0.01)

    local LMin = (2 - S) * VMin
    local SL = (S * VMin) / if LMin <= 1 then LMin else 2 - LMin

    return H, if SL > 0 then SL * 100 else 0, (((2 - S) * V) / 2) * 100
end

-- http://dev.w3.org/csswg/css-color/#hwb-to-rgb
local function HWB_RGB(H: number, W: number, B: number)
    local H = H / 360
    local WH = W / 100
    local BL = B / 100
    local Ratio = WH + BL

    -- Wh + bl cant be > 1
    if Ratio > 1 then
        WH /= Ratio
        BL /= Ratio
    end

    local I = math.floor(6 * H)
    local V = 1 - BL
    local F = 6 * (H - I)

    local NewF = if bit32.band(I, 0x01) ~= 0 then 1 - F else F
    local N = (WH + F) * (V - WH) -- Linear interpolation

    if I == 0 then
        return V * 255, N * 255, WH * 255
    elseif I == 1 then
        return N * 255, V * 255, WH * 255
    elseif I == 2 then
        return WH * 255, V * 255, N * 255
    elseif I == 3 then
        return WH * 255, N * 255, V * 255
    elseif I == 4 then
        return N * 255, WH * 255, V * 255
    elseif I == 5 then
        return V * 255, WH * 255, N * 255
    else
        return 0, 0, 0
    end
end

local function CMYK_RGB(C: number, M: number, Y: number, K: number)
    local C = C / 100
    local M = M / 100
    local Y = Y / 100
    local K = K / 100

    local Multiplier = 1 - K

    return (1 - math.min(1, (C * Multiplier) + K)) * 255,
        (1 - math.min(1, (M * Multiplier) + K)) * 255,
        (1 - math.min(1, (Y * Multiplier) + K)) * 255
end

local XYZToRGBPower = 1.0 / 2.4

local function XYZ_RGB(X: number, Y: number, Z: number)
    local X = X / 100
    local Y = Y / 100
    local Z = Z / 100

    local R = ((X * 3.2404542) + (Y * -1.5371385)) + (Z * -0.4985314)
    local G = ((X * -0.969266) + (Y * 1.8760108)) + (Z * 0.041556)
    local B = ((X * 0.0556434) + (Y * -0.2040259)) + (Z * 1.0572252)

	-- Assume sRGB
	local NewR = if R > 0.0031308 then
            ((1.055 * (R ^ XYZToRGBPower)) - 0.055)
        else
            R * 12.92

    local NewG = if G > 0.0031308 then
            ((1.055 * (G ^ XYZToRGBPower)) - 0.055)
        else
            G * 12.92

    local NewB = if B > 0.0031308 then
            ((1.055 * (B ^ XYZToRGBPower)) - 0.055)
        else
            B * 12.92

    return math.min(math.max(0, NewR), 1) * 255,
        math.min(math.max(0, NewG), 1) * 255,
        math.min(math.max(0, NewB), 1) * 255
end

local XYZToLabIncrement = 16 / 116
local XYZToLabPower = 1 / 3

local function XYZ_LAB(X: number, Y: number, Z: number)
    local X = X / 95.047
    local Y = Y / 100
    local Z = Z / 108.883

    local NewX = if X > LAB_FT then (X ^ XYZToLabPower) else (7.787 * X) + XYZToLabIncrement
    local NewY = if Y > LAB_FT then (Y ^ XYZToLabPower) else (7.787 * Y) + XYZToLabIncrement
    local NewZ = if Z > LAB_FT then (Z ^ XYZToLabPower) else (7.787 * Z) + XYZToLabIncrement

    return (116 * NewY) - 16,
        500 * (NewX - NewY),
        200 * (NewY - NewZ)
end

local LABToXYZSubtractor = 16 / 166
local LABToXYZDivider = 7.787

local function LAB_XYZ(L: number, A: number, B: number)
    local Y = (L + 16) / 116
    local X = (A / 500) + Y
    local Z = (Y - B) / 200

    local Y2 = Y ^ 3
    local X2 = X ^ 3
    local Z2 = Z ^ 3
    local NewY = if Y2 > LAB_FT then Y2 else (Y - LABToXYZSubtractor) / LABToXYZDivider
    local NewX = if X2 > LAB_FT then X2 else (X - LABToXYZSubtractor) / LABToXYZDivider
    local NewZ = if Z2 > LAB_FT then Z2 else (Z - LABToXYZSubtractor) / LABToXYZDivider

    -- Illuminant D65 XYZ Tristrimulus Values
	-- https://en.wikipedia.org/wiki/CIE_1931_color_space
    return NewX * 95.047, NewY * 100, NewZ * 108.883
end

local LABToLCHDivider = 2 / math.pi

local function LAB_LCH(L: number, A: number, B: number)
    local H = (math.atan2(B, A) * 360) / LABToLCHDivider

    return L, math.sqrt((A * A) + (B * B)), 
		if H < 0 then H + 360 else H
end

local Tau = math.pi * 2

local function LCH_LAB(L: number, C: number, H: number)
	local HR = (H / 360) * Tau
	return L, C * math.cos(HR), C * math.sin(HR)
end

local function RGB_Ansi16(R: number, G: number, B: number, Saturation: number?)
	local Saturation = math.floor((Saturation or (select(2, RGB_HSV(R, G, B)))) / 50)
	if Saturation == 0 then return 30 end

	local Ansi = 30 + bit32.bor(
		math.floor(bit32.lshift((B / 255), 2)),
		math.floor(bit32.lshift((G / 255), 1)),
		math.floor(R / 255)
	)

	return if Saturation == 2 then Ansi + 60 else Ansi
end

local function HSV_Ansi16(H: number, S: number, V: number)
	-- Optimization here; we already know the value and don't need to get
	-- it converted for us.
	return RGB_Ansi16(HSV_RGB(H, S, V), V)
end

local function RGB_Ansi256(R: number, G: number, B: number)
	-- We use the extended greyscale palette here, with the exception of
	-- black and white. normal palette only has 4 greyscale shades.
	if bit32.rshift(R, 4) == bit32.rshift(G, 4) and bit32.rshift(G, 4) == bit32.rshift(B, 4) then
		if R < 8 then
			return 16
		elseif R > 248 then
			return 231
		else
			return math.floor(((R - 8) / 247) * 24) + 232
		end
	end

	return 16 + (36 * math.floor((R / 255) * 5))
		+ (6 * math.floor((G / 255) * 5))
		+ math.floor((B / 255) * 5)
end

local function Ansi16_RGB(Ansi16: number)
	local Color = Ansi16 % 10

	-- Handle greyscale
	if Color == 0 or Color == 7 then
		local NewColor = (if Ansi16 > 50 then Color + 3.5 else Color) / (10.5 * 255)
		return NewColor, NewColor, NewColor
	end
	local Mult = bit32.band(if Ansi16 > 50 then 1 else 0 + 1, u32ConversionHex) * 0.5
	
	return (bit32.band(Color, 1) * Mult) * 255,
		(bit32.band(bit32.rshift(Color, 1), 1) * Mult) * 255,
		(bit32.band(bit32.rshift(Color, 2), 1) * Mult) * 255
end

local function Ansi16_Color3(Ansi16: number)
	return Color3.fromRGB(Ansi16_RGB(Ansi16))
end

local function Ansi256_RGB(Ansi256: number)
	-- Handle greyscale
	if Ansi256 >= 232 then
		local Color = ((Ansi256 - 232) * 10) + 8
		return Color, Color, Color
	end
	local Color = Ansi256 - 16
	local Rem = Color % 36

	return (math.floor(Color / 36) / 5) * 255,
		(math.floor(Rem / 6) / 5) * 255,
		((Rem % 6) / 5) * 255
end

local function Ansi256_Color3(Ansi256: number)
	return Color3.fromRGB(Ansi256_RGB(Ansi256))
end

local function RGB_HEX(R: number, G: number, B: number)
	return string.format("#%X%X%X", R, G, B)
end

local function HEX_RGB(Hex: string)
	local Hex = string.gsub(Hex, "#", "")
	return tonumber(`0x{string.sub(Hex, 1, 2)}`), 
		tonumber(`0x{string.sub(Hex, 3, 4)}`),
		tonumber(`0x{string.sub(Hex, 5, 6)}`)
end

local function RGB_HCG(R: number, G: number, B: number)
	local R = R / 255
	local G = G / 255
	local B = B / 255
	local Max = math.max(R, G, B)
	local Min = math.min(R, G, B)
	local Chroma = Max - Min
	local Hue = (
		if Chroma <= 0 then
			0
		elseif Max == R then
			((G - B) / Chroma) % 6
		elseif Max == G then
			(2 + (B - R)) / Chroma
		else
			(4 + (R - G)) / Chroma
	) / 6

	return (Hue % 1) * 360, Chroma * 100, 
		(if Chroma < 1 then Min / (1 - Chroma) else 0) * 100
end

local function HSL_HCG(H: number, S: number, L: number)
	local S = S / 100
	local L = L / 100
	local C = if L < 0.5 then (2 * S) * L else (2 * S)  * (1 - L)

	return H, C * 100, 
		if C < 1 then (((L - 0.5) * C) / (1 - C)) * 100 else 0
end

local function HSV_HCG(H: number, S: number, V: number)
	local S = S / 100
	local V = V / 100
	local C = S * V

	return H, C * 100,
		if C < 1 then ((V - C) / (1 - C)) * 100 else 0
end

local function HCG_RGB(H: number, C: number, G: number)
	local H = H / 360
	local C = C / 100
	local G = G / 100

	if C == 0 then
		local Value = G * 255
		return Value, Value, Value
	end

	local PureR = 0
	local PureG = 0
	local PureB = 0
	local HI = (H % 1) * 6
	local MG = (1 - C) * G
	local V = HI % 1
	local W = 1 - V

	local FlooredHI = math.floor(HI)

	if FlooredHI == 0 then
		return ((C * 1) + MG) * 255, ((C * V) + MG) * 255, 0

	elseif FlooredHI == 1 then
		return ((C * W) + MG) * 255, ((C * 1) + MG) * 255, 0

	elseif FlooredHI == 2 then 
		return 0, ((C * 1) + MG) * 255, ((C * V) + MG) * 255

	elseif FlooredHI == 3 then
		return 0, ((C * W) + MG) * 255, ((C * 1) + MG) * 255

	elseif FlooredHI == 4 then
		return ((C * V) + MG) * 255, 0, ((C * 1) + MG) * 255

	else
		return ((C * 1) + MG) * 255, 0, ((C * W) + MG) * 255

	end
end

local function HCG_Color3(H: number, C: number, G: number)
	return Color3.fromRGB(HCG_RGB(H, C, G))
end

local function HCG_HSV(H: number, C: number, G: number)
	local C = C / 100
	local G = G / 100
	local V = (C + G) * (1 - C)

	return H, if V > 0 then (C / V) * 100 else 0, V * 100
end

local function HCG_HSL(H: number, C: number, G: number)
	local C = C / 100
	local G = G / 100
	local L = ((G * (1 - C)) + 0.5) * C
	
	local S = if L > 0 and L < 0.5 then
			C / (2 * L)
		elseif L >= 0.5 and L < 1 then
			C / (2 * (1 - L))
		else
			0

	return H, S * 100, L * 100
end

local function HCG_HWB(H: number, C: number, G: number)
	local C = C / 100
	local G = G / 100

	return H, (V - C) * 100, (1 - ((C + G) * (1 - C))) * 100
end

local function HWB_HCG(H: number, W: number, B: number)
	local W = W / 100
	local B = B / 100
	local V = 1 - B
	local C = V - W

	return H, C * 100, if C < 1 then ((V - C) / (1 - C)) * 100 else 0 
end

local function Apple_RGB(R16: number, G16: number, B16: number)
	return (R16 / 65535) * 255, (G16 / 65535) * 255, (B16 / 65535) * 255
end

local function Apple_Color3(R16: number, G16: number, B16: number)
	return Color3.new(R16 / 65535, G16 / 65535, B16 / 65535)
end

local function RGB_Apple(R: number, G: number, B: number)
	return (R / 255) * 65535, (G / 255) * 65535, (B / 255) * 65535
end

local function Grey_RGB(Grey: number)
	local Color = (Grey / 100) * 255
	return Color, Color, Color
end

local function Grey_Color3(Grey: number)
	return Color3.fromRGB(Grey_RGB(Grey))
end

local function Grey_HSL(Grey: number)
	return 0, 0, Grey
end

local function Grey_HWB(Grey: number)
	return 0, 100, Grey
end

local function Grey_CMYK(Grey: number)
	return 0, 0, 0, Grey
end

local function Grey_LAB(Grey: number)
	return Grey, 0, 0
end

local function Grey_HEX(Grey: number)
	local Value = bit32.band(math.floor((Grey / 100) * 255), 0xFF)

	return string.format(
		"#%X", bit32.lshift(Value, 16) + bit32.lshift(Value, 8) + Value
	)
end

local function RGB_Grey(R: number, G: number, B: number)
	return (((R + G + B) / 3) / 255) * 100
end

local function Color3_RGB(Color3: Color3)
	return math.clamp(math.ceil(Color3.R * 255), 0, 255),
		math.clamp(math.ceil(Color3.G * 255), 0, 255),
		math.clamp(math.ceil(Color3.B * 255), 0, 255)
end

local function Color3_Grey(Color3: Color3)
	return RGB_Grey(Color3_RGB(Color3))
end

local function Color3_HSV(Color3: Color3)
	return RGB_HSV(Color3_RGB(Color3))
end

local function Color3_HEX(Color3: Color3)
	return RGB_HEX(Color3_RGB(Color3))
end

local function HSL_Color3(H: number, S: number, L: number)
	return Color3.fromRGB(HSL_RGB(H, S, L))
end

local function HWB_Color3(H: number, W: number, B: number)
	return Color3.fromRGB(HWB_RGB(H, W, B))
end

local function XYZ_Color3(X: number, Y: number, Z: number)
	return Color3.fromRGB(XYZ_RGB(X, Y, Z))
end

local function CMYK_Color3(C: number, M: number, Y: number, K: number)
	return Color3.fromRGB(CMYK_RGB(C, M, Y, K))
end

local function Color3_HSL(Color3: Color3)
	return RGB_HSL(Color3_RGB(Color3))
end

local function Color3_LAB(Color3: Color3)
	return RGB_LAB(Color3_RGB(Color3))
end

local function Color3_HCG(Color3: Color3)
	return RGB_HCG(Color3_RGB(Color3))
end

local function Color3_HWB(Color3: Color3)
	return RGB_HWB(Color3_RGB(Color3))
end

local Exports = table.freeze({
	RGB = table.freeze({
		Color3 = (if Color3 then Color3.fromRGB else function() end) :: (R: number, G: number, B: number) -> Color3,
		Ansi256 = RGB_Ansi256,
		Ansi16 = RGB_Ansi16,
		Apple = RGB_Apple,
		CMYK = RGB_CMYK,
		Grey = RGB_Grey,
		HSL = RGB_HSL,
		HCG = RGB_HCG,
		HEX = RGB_HEX,
		HWB = RGB_HWB,
		LAB = RGB_LAB,
		XYZ = RGB_XYZ,
		HSV = RGB_HSV,

		Channels = 3, 
		Label = "RGB"
	}),
	HSL = table.freeze({
		Color3 = HSL_Color3,
		HCG = HSL_HCG,
		HSV = HSL_HSV,
		RGB = HSL_RGB,

		Channels = 3,
		Label = "HSL"
	}),
	HSV = table.freeze({
		Color3 = (if Color3 then Color3.fromHSV else function() end) :: (H: number, S: number, V: number) -> Color3,
		Ansi16 = HSV_Ansi16,
		HCG = HSV_HCG,
		HSL = HSV_HSL,
		RGB = HSV_RGB,

		Channels = 3,
		Label = "HSV"
	}),
	HWB = table.freeze({
		Color3 = HWB_Color3,
		HCG = HWB_HCG,
		RGB = HWB_RGB,

		Channels = 3, 
		Label = "HWB"
	}),
	CMYK = table.freeze({
		Color3 = CMYK_Color3,
		RGB = CMYK_RGB,

		Channels = 4,
		Label = "CMYK"
	}),
	XYZ = table.freeze({
		Color3 = XYZ_Color3,
		LAB = XYZ_LAB,
		RGB = XYZ_RGB,

		Channels = 3,
		Label = "XYZ"
	}),
	LAB = table.freeze({
		LCH = LAB_LCH,
		XYZ = LAB_XYZ,

		Channels = 3,
		Label = "Lab"
	}),
	LCH = table.freeze({
		LAB = LCH_LAB,

		Channels = 3,
		Label = "LCH"
	}),
	HEX = table.freeze({
		Color3 = (if Color3 then Color3.fromHex else function() end) :: (Hex: string) -> Color3,
		RGB = HEX_RGB,

		Channels = 1,
		Label = "HEX"
	}),
	Ansi16 = table.freeze({
		Color3 = Ansi16_Color3,
		RGB = Ansi16_RGB,

		Channels = 1,
		Label = "Ansi16"
	}),
	Ansi256 = table.freeze({
		Color3 = Ansi256_Color3,
		RGB = Ansi256_RGB,

		Channels = 1,
		Label = "Ansi256"
	}),
	HCG = table.freeze({
		Color3 = HCG_Color3,
		HWB = HCG_HWB,
		HSL = HCG_HSL,
		HSV = HCG_HSV,
		RGB = HCG_RGB,

		Channels = 3,
		Labels = table.freeze({"H", "C", "G"})
	}),
	Apple = table.freeze({
		Color3 = Apple_Color3,
		RGB = Apple_RGB,

		Channels = 3,
		Labels = table.freeze({"R16", "G16", "B16"})
	}),
	Grey = table.freeze({
		Color3 = Grey_Color3,
		CMYK = Grey_CMYK,
		HWB = Grey_HWB,
		LAB = Grey_LAB,
		RGB = Grey_RGB,
		HSL = Grey_HSL,
		HSV = Grey_HSL,
		HEX = Grey_HEX,

		Channels = 1,
		Label = "Grey"
	}),
    Color3 = table.freeze({
		Grey = Color3_Grey,
		HEX = Color3_HEX,
		HSL = Color3_HSL,
		HSV = Color3_HSV,
		RGB = Color3_RGB,
		LAB = Color3_LAB,
		HWB = Color3_HWB,
		HCG = Color3_HCG,

		Channels = 3, 
		Label = "Color3"
	})
})

return Exports 