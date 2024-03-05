--!optimize 2
--!strict
--!native

-- ImageData
-- Basic editable image pixels wrapper class
-- @Kalrnlo
-- 03/03/2024

type ImageDataPrototype<T> = {
	Set: (self: ImageData<T>, Index: number, R: number, G: number, B: number, A: number?) -> (),
	__iter: (self: ImageData<T>) -> () -> (number, number, number, number, number),
	Peek: (self: ImageData<T>, Index: number) -> (number, number, number, number),
	Iter: (self: ImageData<T>) -> () -> (number, number, number, number, number),
	__len: (self: ImageData<T>) -> number,
}

export type ImageData<T> = typeof(setmetatable({} :: {
	Pixels: T & ({number} | buffer),
	Height: number,
	Width: number,
	Size: number,
}, {} :: ImageDataPrototype<T>))

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
			return buffer.readu8(self.Pixels :: any, Index),
				buffer.readu8(self.Pixels :: any, Index + 1),
				buffer.readu8(self.Pixels :: any, Index + 2),
				buffer.readu8(self.Pixels :: any, Index + 3)
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
				error("[ImageData] Iterator tried to go out of bounds")
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
				error("[ImageData] Iterator tried to go out of bounds")
			end

			-- Index, R, G, B, A
			return Index, buffer.readu8(self.Pixels :: any, Index),
				buffer.readu8(self.Pixels :: any, Index + 1),
				buffer.readu8(self.Pixels :: any, Index + 2),
				buffer.readu8(self.Pixels :: any, Index + 3)
		end
	end
end

local function ImageData_Set<T>(
	self: ImageData<T>,
	Index: number,
	R: number,
	G: number,
	B: number,
	A: number?
)
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
			buffer.writeu8(self.Pixels :: any, NewIndex, R)
			buffer.writeu8(self.Pixels :: any, NewIndex + 1, G)
			buffer.writeu8(self.Pixels :: any, NewIndex + 2, B)
			buffer.writeu8(self.Pixels :: any, NewIndex + 3, A)
		end
	end
end

local function ImageData_Len<T>(self: ImageData<T>)
	return self.Size
end

local ImageDataPrototype = {
	__iter = ImageData_Iter,
	__len = ImageData_Len,
	Iter = ImageData_Iter,
	Peek = ImageData_Peek,
	Set = ImageData_Set,
}
ImageDataPrototype.__index = ImageDataPrototype

local function FromArray(Pixels: {number}, Width: number, Height: number, Copy: boolean?): ImageData<{number}>
	local CopyPixels = if Copy == nil then true else Copy
	local NewPixels = if CopyPixels then table.clone(Pixels) else Pixels

	return setmetatable({
		Size = #NewPixels / 4,
		Pixels = NewPixels,
		Height = Height,
		Width = Width,
	}, ImageDataPrototype) :: any
end

local function FromBuffer(Pixels: buffer, Width: number, Height: number, Copy: boolean?): ImageData<buffer>
	local Length = buffer.len(Pixels)
	local CopyPixels = if Copy == nil then true else Copy
	local NewPixels = if CopyPixels then buffer.create(Length) else Pixels

	if CopyPixels then
		buffer.copy(NewPixels, 0, Data)
	end

	return setmetatable({
		Pixels = NewPixels,
		Height = Height,
		Width = Width,
		Size = Length / 4,
	}, ImageDataPrototype) :: any
end

local function FromEditableImage(EditableImage: EditableImage): ImageData<{number}>
	local Pixels = EditableImage:ReadPixels(Vector2.new(), EditableImage.Size)

	return setmetatable({
		Pixels = Data:ReadPixels(Vector2.new(), Data.Size),
		Height = EditableImage.Size.Y,
		Width = EditableImage.Size.X,
		Size = #Pixels / 4,
	}, ImageDataPrototype) :: any
end

local Exports = table.freeze({
	fromEditableImage = FromEditableImage,
	fromBuffer = FromBuffer,
	fromArray = FromArray,
})

return Exports