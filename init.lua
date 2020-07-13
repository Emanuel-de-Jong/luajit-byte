local bit = require('bit')
local ffi = require('ffi')

local bad_argument_pattern = "bad argument (%s expected, got %s)"

local assert_type = function(value, _type)
	return assert(
		type(value) == _type,
		bad_argument_pattern:format(_type, type(value))
	)
end

local assert_ctype = function(object, ctype)
	assert(
		type(object) == "cdata",
		bad_argument_pattern:format(ffi.typeof(ctype), type(object))
	)
	assert(
		ffi.istype(ctype, object),
		bad_argument_pattern:format(ffi.typeof(ctype), ffi.typeof(object))
	)
end

local bad_numeric_pattern = "bad argument (number or ctype<uint64_t> expected, got %s)"

local assert_numeric
do
	local uint64_t = ffi.typeof("uint64_t")

	assert_numeric = function(value)
		if type(value) == "cdata" then
			return assert(
				ffi.istype(uint64_t, value),
				bad_numeric_pattern:format(ffi.typeof(value))
			)
		else
			return assert(
				tonumber(value),
				bad_numeric_pattern:format(type(value))
			)
		end
	end
end

--------------------------------------------------------------------------------

local string_to_uint8 = function(s)
	assert_type(s, "string")
	assert(#s == 1)
	return s:byte()
end

local string_to_int8 = function(s)
	local n = string_to_uint8(s)
	return n < 0x80 and n or -0x100 + n
end

local string_to_uint16_le = function(s)
	assert_type(s, "string")
	assert(#s == 2)
	local a, b = s:byte(1, -1)
	return bit.lshift(b, 8) + a
end

local string_to_uint16_be = function(s)
	assert_type(s, "string")
	assert(#s == 2)
	local a, b = s:byte(1, -1)
	return bit.lshift(a, 8) + b
end

local string_to_int16_le = function(s)
	local n = string_to_uint16_le(s)
	return n < 0x8000 and n or -0x10000 + n
end

local string_to_int16_be = function(s)
	local n = string_to_uint16_be(s)
	return n < 0x8000 and n or -0x10000 + n
end

local string_to_int32_le = function(s)
	assert_type(s, "string")
	assert(#s == 4)
	local a, b, c, d = s:byte(1, -1)
	return
		  bit.lshift(d, 24)
		+ bit.lshift(c, 16)
		+ bit.lshift(b, 8)
		+            a
end

local string_to_int32_be = function(s)
	assert_type(s, "string")
	assert(#s == 4)
	local a, b, c, d = s:byte(1, -1)
	return
		  bit.lshift(a, 24)
		+ bit.lshift(b, 16)
		+ bit.lshift(c, 8)
		+            d
end

local string_to_uint32_le
local string_to_uint32_be
do
	local int32_pointer = ffi.new("int32_t[1]")
	local uint32_pointer = ffi.cast("uint32_t*", int32_pointer)

	string_to_uint32_le = function(s)
		int32_pointer[0] = string_to_int32_le(s)
		return uint32_pointer[0]
	end

	string_to_uint32_be = function(s)
		int32_pointer[0] = string_to_int32_be(s)
		return uint32_pointer[0]
	end
end

local string_to_int64_le
local string_to_int64_be
local string_to_uint64_le
local string_to_uint64_be
do
	local char_pointer = ffi.new("char[8]")
	local int64_pointer = ffi.cast("int64_t*", char_pointer)
	local uint64_pointer = ffi.cast("uint64_t*", char_pointer)

	string_to_int64_le = function(s)
		assert_type(s, "string")
		assert(#s == 8)
		ffi.copy(char_pointer, s, 8)
		return int64_pointer[0]
	end

	string_to_int64_be = function(s)
		assert_type(s, "string")
		assert(#s == 8)
		ffi.copy(char_pointer, s:reverse(), 8)
		return int64_pointer[0]
	end

	string_to_uint64_le = function(s)
		assert_type(s, "string")
		assert(#s == 8)
		ffi.copy(char_pointer, s, 8)
		return uint64_pointer[0]
	end

	string_to_uint64_be = function(s)
		assert_type(s, "string")
		assert(#s == 8)
		ffi.copy(char_pointer, s:reverse(), 8)
		return uint64_pointer[0]
	end
end

--------------------------------------------------------------------------------

local int32_to_float
do
	local int32_pointer = ffi.new("int32_t[1]")
	local float_pointer = ffi.cast("float*", int32_pointer)

	int32_to_float = function(n)
		assert_type(n, "number")
		int32_pointer[0] = n
		return tonumber(float_pointer[0])
	end
end

local float_to_int32
do
	local float_pointer = ffi.new("float[1]")
	local int32_pointer = ffi.cast("int32_t*", float_pointer)

	float_to_int32 = function(n)
		assert_type(n, "number")
		float_pointer[0] = n
		return tonumber(int32_pointer[0])
	end
end

local string_to_float_le = function(s)
	return int32_to_float(string_to_int32_le(s))
end

local string_to_float_be = function(s)
	return int32_to_float(string_to_int32_be(s))
end

--------------------------------------------------------------------------------

local int64_to_double
do
	local int64_pointer = ffi.new("int64_t[1]")
	local double_pointer = ffi.cast("double*", int64_pointer)
	local int64_t = ffi.typeof("int64_t")

	int64_to_double = function(n)
		assert_ctype(n, int64_t)
		int64_pointer[0] = n
		return tonumber(double_pointer[0])
	end
end

local double_to_int64
do
	local double_pointer = ffi.new("double[1]")
	local int64_pointer = ffi.cast("int64_t*", double_pointer)

	double_to_int64 = function(n)
		assert_type(n, "number")
		double_pointer[0] = n
		return int64_pointer[0]
	end
end

local string_to_double_le = function(s)
	return int64_to_double(string_to_int64_le(s))
end

local string_to_double_be = function(s)
	return int64_to_double(string_to_int64_be(s))
end

--------------------------------------------------------------------------------

local int8_to_string = function(n)
	assert_type(n, "number")
	return string.char(bit.band(n, 0x000000ff))
end

local int16_to_string_le = function(n)
	assert_type(n, "number")
	return string.char(
		           bit.band(n, 0x000000ff),
		bit.rshift(bit.band(n, 0x0000ff00), 8)
	)
end

local int16_to_string_be = function(n)
	assert_type(n, "number")
	return string.char(
		bit.rshift(bit.band(n, 0x0000ff00), 8),
		           bit.band(n, 0x000000ff)
	)
end

local int32_to_string_le = function(n)
	assert_type(n, "number")
	return string.char(
		           bit.band(n, 0x000000ff),
		bit.rshift(bit.band(n, 0x0000ff00), 8),
		bit.rshift(bit.band(n, 0x00ff0000), 16),
		bit.rshift(bit.band(n, 0xff000000), 24)
	)
end

local int32_to_string_be = function(n)
	assert_type(n, "number")
	return string.char(
		bit.rshift(bit.band(n, 0xff000000), 24),
		bit.rshift(bit.band(n, 0x00ff0000), 16),
		bit.rshift(bit.band(n, 0x0000ff00), 8),
		           bit.band(n, 0x000000ff)
	)
end

local int64_to_string_le
local int64_to_string_be
do
	local int64_pointer = ffi.new("int64_t[1]")
	local char_pointer = ffi.cast("char*", int64_pointer)
	local int64_t = ffi.typeof("int64_t")

	int64_to_string_le = function(n)
		assert_ctype(n, int64_t)
		int64_pointer[0] = n
		return ffi.string(char_pointer, 8)
	end

	int64_to_string_be = function(n)
		assert_ctype(n, int64_t)
		int64_pointer[0] = n
		return ffi.string(char_pointer, 8):reverse()
	end
end

local uint64_to_string_le
local uint64_to_string_be
do
	local uint64_pointer = ffi.new("uint64_t[1]")
	local char_pointer = ffi.cast("char*", uint64_pointer)
	local uint64_t = ffi.typeof("uint64_t")

	uint64_to_string_le = function(n)
		assert_ctype(n, uint64_t)
		uint64_pointer[0] = n
		return ffi.string(char_pointer, 8)
	end

	uint64_to_string_be = function(n)
		assert_ctype(n, uint64_t)
		uint64_pointer[0] = n
		return ffi.string(char_pointer, 8):reverse()
	end
end

local float_to_string_le = function(n)
	return int32_to_string_le(float_to_int32(n))
end

local float_to_string_be = function(n)
	return int32_to_string_be(float_to_int32(n))
end

local double_to_string_le = function(n)
	return int64_to_string_le(double_to_int64(n))
end

local double_to_string_be = function(n)
	return int64_to_string_be(double_to_int64(n))
end

--------------------------------------------------------------------------------

local byte = {}

byte.string_to_uint8 = string_to_uint8
byte.string_to_int8 = string_to_int8
byte.string_to_uint16_le = string_to_uint16_le
byte.string_to_uint16_be = string_to_uint16_be
byte.string_to_int16_le = string_to_int16_le
byte.string_to_int16_be = string_to_int16_be
byte.string_to_uint32_le = string_to_uint32_le
byte.string_to_uint32_be = string_to_uint32_be
byte.string_to_int32_le = string_to_int32_le
byte.string_to_int32_be = string_to_int32_be

byte.string_to_int64_le = string_to_int64_le
byte.string_to_int64_be = string_to_int64_be
byte.string_to_uint64_le = string_to_uint64_le
byte.string_to_uint64_be = string_to_uint64_be

byte.int32_to_float = int32_to_float
byte.float_to_int32 = float_to_int32
byte.string_to_float_le = string_to_float_le
byte.string_to_float_be = string_to_float_be

byte.int64_to_double = int64_to_double
byte.double_to_int64 = double_to_int64
byte.string_to_double_le = string_to_double_le
byte.string_to_double_be = string_to_double_be

byte.int8_to_string = int8_to_string
byte.int16_to_string_le = int16_to_string_le
byte.int16_to_string_be = int16_to_string_be
byte.int32_to_string_le = int32_to_string_le
byte.int32_to_string_be = int32_to_string_be

byte.int64_to_string_le = int64_to_string_le
byte.int64_to_string_be = int64_to_string_be
byte.uint64_to_string_le = uint64_to_string_le
byte.uint64_to_string_be = uint64_to_string_be

byte.float_to_string_le = float_to_string_le
byte.float_to_string_be = float_to_string_be
byte.double_to_string_le = double_to_string_le
byte.double_to_string_be = double_to_string_be

--------------------------------------------------------------------------------

local assert_freed = function(self)
	return assert(self.size ~= 0, "buffer was already freed")
end

local _total = ffi.new("size_t")

local total = function()
	return _total
end

local resize = function(self, newsize)
	assert_freed(self)
	assert_numeric(newsize)
	assert(newsize > 0, "buffer size must be greater than zero")

	local pointer = ffi.C.realloc(self.pointer, newsize)
	assert(pointer ~= nil, "allocation error")
	self.pointer = pointer

	_total = _total + newsize - self.size
	self.size = newsize

	self.offset = self.offset < newsize and self.offset or newsize

	return self
end

local free = function(self)
	assert_freed(self)

	ffi.C.free(self.pointer)
	ffi.gc(self, nil)

	_total = _total - self.size

	self.size = 0
end

local gc = function(self, state)
	assert_freed(self)
	assert_type(state, "boolean")

	if state then
		ffi.gc(self, free)
	else
		ffi.gc(self, nil)
	end

	return self
end

local seek = function(self, offset)
	assert_freed(self)
	assert_numeric(offset)
	assert(offset >= 0 and offset <= self.size, "attempt to perform seek outside buffer bounds")

	self.offset = offset

	return self
end

local fill = function(self, s)
	assert_freed(self)
	assert_type(s, "string")

	local length = #s
	local offset = self.offset
	assert(offset + length <= self.size, "attempt to write outside buffer bounds")

	self.offset = offset + length

	ffi.copy(self.pointer + offset, s, length)

	return self
end

local _string = function(self, length)
	assert_freed(self)
	assert_numeric(length)

	local offset = self.offset

	assert(length >= 0, "length cannot be less than zero")
	assert(offset + length <= self.size, "attempt to read after end of buffer")

	self.offset = offset + length

	return ffi.string(self.pointer + offset, length)
end

local _cstring = function(self, length)
	assert_freed(self)
	assert_numeric(length)

	local offset = self.offset

	assert(length >= 0, "length cannot be less than zero")
	assert(offset + length <= self.size, "attempt to read after end of buffer")

	self.offset = offset + length

	local s = ffi.string(self.pointer + offset)
	if #s > length then
		return ffi.string(self.pointer + offset, length)
	end

	return s
end

local uint8 = function(self, n)
	if n then return fill(self, int8_to_string(n)) end
	return string_to_uint8(_string(self, 1))
end

local int8 = function(self, n)
	if n then return fill(self, int8_to_string(n)) end
	return string_to_int8(_string(self, 1))
end

local uint16_le = function(self, n)
	if n then return fill(self, int16_to_string_le(n)) end
	return string_to_uint16_le(_string(self, 2))
end

local uint16_be = function(self, n)
	if n then return fill(self, int16_to_string_be(n)) end
	return string_to_uint16_be(_string(self, 2))
end

local int16_le = function(self, n)
	if n then return fill(self, int16_to_string_le(n)) end
	return string_to_int16_le(_string(self, 2))
end

local int16_be = function(self, n)
	if n then return fill(self, int16_to_string_be(n)) end
	return string_to_int16_be(_string(self, 2))
end

local uint32_le = function(self, n)
	if n then return fill(self, int32_to_string_le(n)) end
	return string_to_uint32_le(_string(self, 4))
end

local uint32_be = function(self, n)
	if n then return fill(self, int32_to_string_be(n)) end
	return string_to_uint32_be(_string(self, 4))
end

local int32_le = function(self, n)
	if n then return fill(self, int32_to_string_le(n)) end
	return string_to_int32_le(_string(self, 4))
end

local int32_be = function(self, n)
	if n then return fill(self, int32_to_string_be(n)) end
	return string_to_int32_be(_string(self, 4))
end

local uint64_le = function(self, n)
	if n then return fill(self, uint64_to_string_le(n)) end
	return string_to_uint64_le(_string(self, 8))
end

local uint64_be = function(self, n)
	if n then return fill(self, uint64_to_string_be(n)) end
	return string_to_uint64_be(_string(self, 8))
end

local int64_le = function(self, n)
	if n then return fill(self, int64_to_string_le(n)) end
	return string_to_int64_le(_string(self, 8))
end

local int64_be = function(self, n)
	if n then return fill(self, int64_to_string_be(n)) end
	return string_to_int64_be(_string(self, 8))
end

local float_le = function(self, n)
	if n then return fill(self, float_to_string_le(n)) end
	return int32_to_float(string_to_uint32_le(_string(self, 4)))
end

local float_be = function(self, n)
	if n then return fill(self, float_to_string_be(n)) end
	return int32_to_float(string_to_uint32_be(_string(self, 4)))
end

local double_le = function(self, n)
	if n then return fill(self, double_to_string_le(n)) end
	return int64_to_double(string_to_int64_le(_string(self, 8)))
end

local double_be = function(self, n)
	if n then return fill(self, double_to_string_be(n)) end
	return int64_to_double(string_to_int64_be(_string(self, 8)))
end

local buffer = {}

buffer.total = total
buffer.resize = resize
buffer.free = free
buffer.gc = gc
buffer.fill = fill
buffer.seek = seek
buffer.string = _string
buffer.cstring = _cstring
buffer.uint8 = uint8
buffer.int8 = int8
buffer.uint16_le = uint16_le
buffer.uint16_be = uint16_be
buffer.int16_le = int16_le
buffer.int16_be = int16_be
buffer.uint32_le = uint32_le
buffer.uint32_be = uint32_be
buffer.int32_le = int32_le
buffer.int32_be = int32_be
buffer.uint64_le = uint64_le
buffer.uint64_be = uint64_be
buffer.int64_le = int64_le
buffer.int64_be = int64_be
buffer.float_le = float_le
buffer.float_be = float_be
buffer.double_le = double_le
buffer.double_be = double_be

--------------------------------------------------------------------------------

ffi.cdef("void * malloc(size_t size);")
ffi.cdef("void * realloc(void * ptr, size_t newsize);")
ffi.cdef("void free(void * ptr);")

ffi.cdef("typedef struct {size_t size; size_t offset; unsigned char * pointer;} buffer_t;")

local mt = {}

mt.__index = function(_, key)
	return buffer[key]
end

local buffer_t = ffi.metatype(ffi.typeof("buffer_t"), mt)

local newbuffer = function(size)
	assert_numeric(size)
	assert(size > 0, "buffer size must be greater than zero")

	local pointer = ffi.C.malloc(size)
	assert(pointer ~= nil, "allocation error")

	local buffer = buffer_t(size, 0, pointer)
	ffi.gc(buffer, free)

	_total = _total + size

	return buffer
end

byte.buffer_t = buffer_t
byte.buffer = newbuffer

return byte
