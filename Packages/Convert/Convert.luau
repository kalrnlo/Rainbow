-- MIT license */
-- eslint-disable no-mixed-operators */
--[[
const cssKeywords = require('color-name');

-- NOTE: conversions should only return primitive values (i.e. arrays, or
--       values that give correct `typeof` results).
--       do not use box values types (i.e. Number(), String(), etc.)

local reverseKeywords = {};

module.exports = convert;

// LAB f(t) constant
const LAB_FT = Math.pow(6 / 29, 3);

// Hide .channels and .labels properties
for (const model of Object.keys(convert)) {
	if (!('channels' in convert[model])) {
		throw new Error('missing channels property: ' + model);
	}

	if (!('labels' in convert[model])) {
		throw new Error('missing channel labels property: ' + model);
	}

	if (convert[model].labels.length !== convert[model].channels) {
		throw new Error('channel and label counts mismatch: ' + model);
	}

	const {channels, labels} = convert[model];
	delete convert[model].channels;
	delete convert[model].labels;
	Object.defineProperty(convert[model], 'channels', {value: channels});
	Object.defineProperty(convert[model], 'labels', {value: labels});
}
--]]

local LAB_FT = math.pow(6 / 29, 3)

local function RGB_HSL(R: number, G: number, B: number)
	local R = R / 255
	local G = G / 255
	local B = B / 255
	local Min = math.min(R, G, B)
	local Max = math.max(R, G, B)
	local L = (Min + Max) / 2
	local Delta = Max - Min

    local H = if R == Max then
            (G - B) / Delta
        elseif G == Max then   
            2 + (B - R) / Delta
        elseif B == Max then
            4 + (R - G) / Delta
        else 
            0

	H = math.min(H * 60, 360)

    if H < 0 then
        H += 360
    end

	local L = (Min + Max) / 2
    local S = (
		if Max == Min then
		    0
	    elseif L <= 0.5 then
		    Delta / (Max + Min)
	    else 
            Delta / ((2 - Max) - Min)
		)

	return H, S * 100, L * 100
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
		local S = Diffrence / V

		local H = if R == V then
				BlueDiffrence - GreenDiffrence
			elseif G == V then
				(1 / 3) + RedDiffrence - BlueDiffrence;
			elseif B == V then
				(2 / 3) + GreenDiffrence - RedDiffrence;
        	else 
				0

		if H < 0 then
			H += 1;
		elseif h > 1 then
			H -= 1
        end

		return H * 360, S * 100, V * 100
	end
end

local function RGB_HWB(R: number, G: number, B: number)
	return (RGB_HSL(R, G, B)), 
		((1 / 255) * math.min(R, math.min(G, B))) * 100, 
		(1 - 1 / 255 * math.max(R, math.max(G, B))) * 100
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

	X = if (X > LAB_FT) > 0 then (X ^ (1 / 3)) else (7.787 * X) + (16 / 116);
	Y = if (Y > LAB_FT) > 0 then (Y ^ (1 / 3)) else (7.787 * Y) + (16 / 116);
	Z = if (Z > LAB_FT) > 0 then (Z ^ (1 / 3)) else (7.787 * Z) + (16 / 116);

	return (116 * Y) - 16, 500 * (X - Y),  200 * (Y - Z)
end

local function HSL_RGB_Helper(Index: number, T1: number, T2: number)
	local T3 = H + 1 / 3 * -(Index - 1)
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

	return HSL_RGB_Helper(0, T1, T2), HSL_RGB_Helper(1, T1, T2), 
		HSL_RGB_Helper(2, T1, T2)
end

local function HSL_HSV(H: number, S: number, L: number)
	local S = S / 100
	local L = L / 100
	local LMin = math.max(L, 0.01)

	L *= 2
	S *= if L <= 1 then L else 2 - l
	local SMin = S * (if LMin <= 1 then LMin else 2 - LMin)
	local V = (L + S) / 2
	local SV = if L == 0 then (2 * SMin) / (LMin + SMin) else (2 * S) / (L + S)

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
	const h = hsv[0];
	const s = hsv[1] / 100;
	const v = hsv[2] / 100;
	const vmin = Math.max(v, 0.01);
	let sl;
	let l;

	l = (2 - s) * v;
	const lmin = (2 - s) * vmin;
	sl = s * vmin;
	sl /= (lmin <= 1) ? lmin : 2 - lmin;
	sl = sl || 0;
	l /= 2;

	return [h, sl * 100, l * 100];
end

-- http://dev.w3.org/csswg/css-color/#hwb-to-rgb
convert.hwb.rgb = function (hwb) {
	const h = hwb[0] / 360;
	let wh = hwb[1] / 100;
	let bl = hwb[2] / 100;
	const ratio = wh + bl;
	let f;

	// Wh + bl cant be > 1
	if (ratio > 1) {
		wh /= ratio;
		bl /= ratio;
	}

	const i = Math.floor(6 * h);
	const v = 1 - bl;
	f = 6 * h - i;

	if ((i & 0x01) !== 0) {
		f = 1 - f;
	}

	const n = wh + f * (v - wh); // Linear interpolation

	let r;
	let g;
	let b;
	/* eslint-disable max-statements-per-line,no-multi-spaces */
	switch (i) {
		default:
		case 6:
		case 0: r = v;  g = n;  b = wh; break;
		case 1: r = n;  g = v;  b = wh; break;
		case 2: r = wh; g = v;  b = n; break;
		case 3: r = wh; g = n;  b = v; break;
		case 4: r = n;  g = wh; b = v; break;
		case 5: r = v;  g = wh; b = n; break;
	}
	/* eslint-enable max-statements-per-line,no-multi-spaces */

	return [r * 255, g * 255, b * 255];
};

convert.cmyk.rgb = function (cmyk) {
	const c = cmyk[0] / 100;
	const m = cmyk[1] / 100;
	const y = cmyk[2] / 100;
	const k = cmyk[3] / 100;

	const r = 1 - Math.min(1, c * (1 - k) + k);
	const g = 1 - Math.min(1, m * (1 - k) + k);
	const b = 1 - Math.min(1, y * (1 - k) + k);

	return [r * 255, g * 255, b * 255];
};

convert.xyz.rgb = function (xyz) {
	const x = xyz[0] / 100;
	const y = xyz[1] / 100;
	const z = xyz[2] / 100;
	let r;
	let g;
	let b;

	r = (x * 3.2404542) + (y * -1.5371385) + (z * -0.4985314);
	g = (x * -0.969266) + (y * 1.8760108) + (z * 0.041556);
	b = (x * 0.0556434) + (y * -0.2040259) + (z * 1.0572252);

	-- Assume sRGB
	r = r > 0.0031308
		? ((1.055 * (r ** (1.0 / 2.4))) - 0.055)
		: r * 12.92;

	g = g > 0.0031308
		? ((1.055 * (g ** (1.0 / 2.4))) - 0.055)
		: g * 12.92;

	b = b > 0.0031308
		? ((1.055 * (b ** (1.0 / 2.4))) - 0.055)
		: b * 12.92;

	r = Math.min(Math.max(0, r), 1);
	g = Math.min(Math.max(0, g), 1);
	b = Math.min(Math.max(0, b), 1);

	return [r * 255, g * 255, b * 255];
};

convert.xyz.lab = function (xyz) {
	let x = xyz[0];
	let y = xyz[1];
	let z = xyz[2];

	x /= 95.047;
	y /= 100;
	z /= 108.883;

	x = x > LAB_FT ? (x ** (1 / 3)) : (7.787 * x) + (16 / 116);
	y = y > LAB_FT ? (y ** (1 / 3)) : (7.787 * y) + (16 / 116);
	z = z > LAB_FT ? (z ** (1 / 3)) : (7.787 * z) + (16 / 116);

	const l = (116 * y) - 16;
	const a = 500 * (x - y);
	const b = 200 * (y - z);

	return [l, a, b];
};

convert.lab.xyz = function (lab) {
	const l = lab[0];
	const a = lab[1];
	const b = lab[2];
	let x;
	let y;
	let z;

	y = (l + 16) / 116;
	x = a / 500 + y;
	z = y - b / 200;

	const y2 = y ** 3;
	const x2 = x ** 3;
	const z2 = z ** 3;
	y = y2 > LAB_FT ? y2 : (y - 16 / 116) / 7.787;
	x = x2 > LAB_FT ? x2 : (x - 16 / 116) / 7.787;
	z = z2 > LAB_FT ? z2 : (z - 16 / 116) / 7.787;

	// Illuminant D65 XYZ Tristrimulus Values
	// https://en.wikipedia.org/wiki/CIE_1931_color_space
	x *= 95.047;
	y *= 100;
	z *= 108.883;

	return [x, y, z];
};

convert.lab.lch = function (lab) {
	const l = lab[0];
	const a = lab[1];
	const b = lab[2];
	let h;

	const hr = Math.atan2(b, a);
	h = hr * 360 / 2 / Math.PI;

	if (h < 0) {
		h += 360;
	}

	const c = Math.sqrt(a * a + b * b);

	return [l, c, h];
};

convert.lch.lab = function (lch) {
	const l = lch[0];
	const c = lch[1];
	const h = lch[2];

	const hr = h / 360 * 2 * Math.PI;
	const a = c * Math.cos(hr);
	const b = c * Math.sin(hr);

	return [l, a, b];
};

convert.rgb.ansi16 = function (args, saturation = null) {
	const [r, g, b] = args;
	let value = saturation === null ? convert.rgb.hsv(args)[2] : saturation; // Hsv -> ansi16 optimization

	value = Math.round(value / 50);

	if (value === 0) {
		return 30;
	}

	let ansi = 30
		+ ((Math.round(b / 255) << 2)
		| (Math.round(g / 255) << 1)
		| Math.round(r / 255));

	if (value === 2) {
		ansi += 60;
	}

	return ansi;
};

convert.hsv.ansi16 = function (args) {
	// Optimization here; we already know the value and don't need to get
	// it converted for us.
	return convert.rgb.ansi16(convert.hsv.rgb(args), args[2]);
};

convert.rgb.ansi256 = function (args) {
	const r = args[0];
	const g = args[1];
	const b = args[2];

	// We use the extended greyscale palette here, with the exception of
	// black and white. normal palette only has 4 greyscale shades.
	if (r >> 4 === g >> 4 && g >> 4 === b >> 4) {
		if (r < 8) {
			return 16;
		}

		if (r > 248) {
			return 231;
		}

		return Math.round(((r - 8) / 247) * 24) + 232;
	}

	const ansi = 16
		+ (36 * Math.round(r / 255 * 5))
		+ (6 * Math.round(g / 255 * 5))
		+ Math.round(b / 255 * 5);

	return ansi;
};

convert.ansi16.rgb = function (args) {
	args = args[0];

	let color = args % 10;

	// Handle greyscale
	if (color === 0 || color === 7) {
		if (args > 50) {
			color += 3.5;
		}

		color = color / 10.5 * 255;

		return [color, color, color];
	}

	const mult = (~~(args > 50) + 1) * 0.5;
	const r = ((color & 1) * mult) * 255;
	const g = (((color >> 1) & 1) * mult) * 255;
	const b = (((color >> 2) & 1) * mult) * 255;

	return [r, g, b];
};

convert.ansi256.rgb = function (args) {
	args = args[0];

	-- Handle greyscale
	if (args >= 232) {
		const c = (args - 232) * 10 + 8;
		return [c, c, c];
	}

	args -= 16;

	let rem;
	const r = Math.floor(args / 36) / 5 * 255;
	const g = Math.floor((rem = args % 36) / 6) / 5 * 255;
	const b = (rem % 6) / 5 * 255;

	return [r, g, b];
};

convert.rgb.hex = function (args) {
	const integer = ((Math.round(args[0]) & 0xFF) << 16)
		+ ((Math.round(args[1]) & 0xFF) << 8)
		+ (Math.round(args[2]) & 0xFF);

	const string = integer.toString(16).toUpperCase();
	return '000000'.substring(string.length) + string;
};

convert.hex.rgb = function (args) {
	const match = args.toString(16).match(/[a-f0-9]{6}|[a-f0-9]{3}/i);
	if (!match) {
		return [0, 0, 0];
	}

	let colorString = match[0];

	if (match[0].length === 3) {
		colorString = colorString.split('').map(char => {
			return char + char;
		}).join('');
	}

	const integer = parseInt(colorString, 16);
	const r = (integer >> 16) & 0xFF;
	const g = (integer >> 8) & 0xFF;
	const b = integer & 0xFF;

	return [r, g, b];
};

convert.rgb.hcg = function (rgb) {
	const r = rgb[0] / 255;
	const g = rgb[1] / 255;
	const b = rgb[2] / 255;
	const max = Math.max(Math.max(r, g), b);
	const min = Math.min(Math.min(r, g), b);
	const chroma = (max - min);
	let grayscale;
	let hue;

	if (chroma < 1) {
		grayscale = min / (1 - chroma);
	} else {
		grayscale = 0;
	}

	if (chroma <= 0) {
		hue = 0;
	} else
	if (max === r) {
		hue = ((g - b) / chroma) % 6;
	} else
	if (max === g) {
		hue = 2 + (b - r) / chroma;
	} else {
		hue = 4 + (r - g) / chroma;
	}

	hue /= 6;
	hue %= 1;

	return [hue * 360, chroma * 100, grayscale * 100];
};

convert.hsl.hcg = function (hsl) {
	const s = hsl[1] / 100;
	const l = hsl[2] / 100;

	const c = l < 0.5 ? (2.0 * s * l) : (2.0 * s * (1.0 - l));

	let f = 0;
	if (c < 1.0) {
		f = (l - 0.5 * c) / (1.0 - c);
	}

	return [hsl[0], c * 100, f * 100];
};

convert.hsv.hcg = function (hsv) {
	const s = hsv[1] / 100;
	const v = hsv[2] / 100;

	const c = s * v;
	let f = 0;

	if (c < 1.0) {
		f = (v - c) / (1 - c);
	}

	return [hsv[0], c * 100, f * 100];
};

convert.hcg.rgb = function (hcg) {
	const h = hcg[0] / 360;
	const c = hcg[1] / 100;
	const g = hcg[2] / 100;

	if (c === 0.0) {
		return [g * 255, g * 255, g * 255];
	}

	const pure = [0, 0, 0];
	const hi = (h % 1) * 6;
	const v = hi % 1;
	const w = 1 - v;
	let mg = 0;

	/* eslint-disable max-statements-per-line */
	switch (Math.floor(hi)) {
		case 0:
			pure[0] = 1; pure[1] = v; pure[2] = 0; break;
		case 1:
			pure[0] = w; pure[1] = 1; pure[2] = 0; break;
		case 2:
			pure[0] = 0; pure[1] = 1; pure[2] = v; break;
		case 3:
			pure[0] = 0; pure[1] = w; pure[2] = 1; break;
		case 4:
			pure[0] = v; pure[1] = 0; pure[2] = 1; break;
		default:
			pure[0] = 1; pure[1] = 0; pure[2] = w;
	}
	/* eslint-enable max-statements-per-line */

	mg = (1.0 - c) * g;

	return [
		(c * pure[0] + mg) * 255,
		(c * pure[1] + mg) * 255,
		(c * pure[2] + mg) * 255
	];
};

convert.hcg.hsv = function (hcg) {
	const c = hcg[1] / 100;
	const g = hcg[2] / 100;

	const v = c + g * (1.0 - c);
	let f = 0;

	if (v > 0.0) {
		f = c / v;
	}

	return [hcg[0], f * 100, v * 100];
};

convert.hcg.hsl = function (hcg) {
	const c = hcg[1] / 100;
	const g = hcg[2] / 100;

	const l = g * (1.0 - c) + 0.5 * c;
	let s = 0;

	if (l > 0.0 && l < 0.5) {
		s = c / (2 * l);
	} else
	if (l >= 0.5 && l < 1.0) {
		s = c / (2 * (1 - l));
	}

	return [hcg[0], s * 100, l * 100];
};

convert.hcg.hwb = function (hcg) {
	const c = hcg[1] / 100;
	const g = hcg[2] / 100;
	const v = c + g * (1.0 - c);
	return [hcg[0], (v - c) * 100, (1 - v) * 100];
};

convert.hwb.hcg = function (hwb) {
	const w = hwb[1] / 100;
	const b = hwb[2] / 100;
	const v = 1 - b;
	const c = v - w;
	let g = 0;

	if (c < 1) {
		g = (v - c) / (1 - c);
	}

	return [hwb[0], c * 100, g * 100];
};

convert.apple.rgb = function (apple) {
	return [(apple[0] / 65535) * 255, (apple[1] / 65535) * 255, (apple[2] / 65535) * 255];
};

convert.rgb.apple = function (rgb) {
	return [(rgb[0] / 255) * 65535, (rgb[1] / 255) * 65535, (rgb[2] / 255) * 65535];
};

convert.gray.rgb = function (args) {
	return [args[0] / 100 * 255, args[0] / 100 * 255, args[0] / 100 * 255];
};

convert.gray.hsl = function (args) {
	return [0, 0, args[0]];
};

convert.gray.hsv = convert.gray.hsl;

convert.gray.hwb = function (gray) {
	return [0, 100, gray[0]];
};

convert.gray.cmyk = function (gray) {
	return [0, 0, 0, gray[0]];
};

convert.gray.lab = function (gray) {
	return [gray[0], 0, 0];
};

convert.gray.hex = function (gray) {
	const val = Math.round(gray[0] / 100 * 255) & 0xFF;
	const integer = (val << 16) + (val << 8) + val;

	const string = integer.toString(16).toUpperCase();
	return '000000'.substring(string.length) + string;
};

local function rgb_gray

convert.rgb.gray = function (rgb) {
	const val = (rgb[0] + rgb[1] + rgb[2]) / 3;
	return [val / 255 * 100];
};

local Exports = {
	RGB = {
		channels = 3, 
		labels = 'rgb'
	},
	HSL = {
		channels = 3,
		labels = 'hsl'
	},
	HSV = {
		channels = 3,
		labels = 'hsv'
	},
	HWB = {
		channels = 3, 
		labels = 'hwb'
	},
	CMYK = {
		channels = 4,
		labels = 'cmyk'
	},
	XYZ = {
		channels = 3,
		labels = 'xyz'
	},
	LAB = {
		channels = 3,
		labels = 'lab'
	},
	LCH = {
		channels = 3,
		labels = 'lch'
	},
	HEX = {
		channels = 1,
		labels = 'hex'
	},
	Ansi16 = {
		channels = 1,
		labels = 'ansi16'
	},
	Ansi256 = {
		channels = 1,
		labels = 'ansi256'
	},
	HCG = {
		channels = 3,
		labels = {'h', 'c', 'g'}
	},
	Apple = {
		channels = 3,
		labels = {'r16', 'g16', 'b16'}
	},
	Gray = {
		channels = 1,
		labels = {"gray"}
	},
    Color3 = {
		channels = 3, 
		labels = "Color3"
	}
};

return Exports 
