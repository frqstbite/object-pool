--!strict

--[=[
	@class ObjectPool<T>

	A container object that manages and rents fungible objects.
]=]
--[=[
	@prop objects number
	@within ObjectPool<T>
	@readonly

	The number of objects currently in the pool.
]=]
--[=[
	@prop minimum number?
	@within ObjectPool<T>
	@readonly

	The minimum number of objects this pool should contain.
]=]
--[=[
	@prop maximum number?
	@within ObjectPool<T>
	@readonly

	The maximum number of objects this pool can contain.
]=]
--[=[
	@prop managed {[T]: true}
	@within ObjectPool<T>
	@private
	@readonly

	Set of all objects this pool manages.
]=]
--[=[
	@prop pool {T}
	@within ObjectPool<T>
	@private
	@readonly

	List of available objects.
]=]
--[=[
	@prop generator () -> T
	@within ObjectPool<T>
	@private
	@readonly

	Function that returns a new instance of an object this pool should manage.
]=]
local ObjectPool = {}
ObjectPool.__index = ObjectPool

export type ObjectPool<T> = typeof(setmetatable({}, ObjectPool)) & {
	-- Properties
	objects: number,
	minimum: number?,
	maximum: number?,

	_managed: {[T]: true},
	_pool: {T},
	_generator: () -> T,
}

--[=[
	Creates a new ObjectPool.

	:::info note
	The maximum, if provided, must be greater than or equal to the minimum, if provided.
	:::

	
	@within ObjectPool<T>

	@param generator () -> T -- Function that returns a new instance of an object this pool should manage.
	@param minimum number? -- The minimum amount of objects this ObjectPool should contain.
	@param maximum number? -- The maximum amount of objects this ObjectPool can contain. Further requests will throw an error.
	
	@return ObjectPool<T>
]=]
function ObjectPool.new<T>(generator: () -> T, minimum: number?, maximum: number?)
	if minimum and maximum and minimum > maximum then
		error("ObjectPool minimum cannot be greater than its maximum")
	end
	
	local self = setmetatable({
		_generator = generator,
		_managed = {},
		_pool = {},

		objects = 0,
		minimum = minimum,
		maximum = maximum,
	}, ObjectPool) :: ObjectPool<T>
	
	-- Populate pool with minimum objects
	if minimum then
		for i = 1, minimum do
			self:_generate()
		end
	end
	
	return self
end

--[=[
	Create and register a managed object to this pool

	:::caution
	If the object pool already contains the maximum number of objects, this will throw an error.
	:::

	@method _generate
	@within ObjectPool<T>
	@private

	@return T -- The generated object.
]=]
function ObjectPool._generate<T>(self: ObjectPool<T>): T
	if self.maximum and #self._pool >= self.maximum then
		error("Attempt to generate new object for full ObjectPool")
	end
	
	local object = self._generator()
	table.insert(self._pool, object)
	self._managed[object] = true
	self.objects += 1
	
	return object
end

--[=[
	Borrows an object from the ObjectPool, creating a new one if none are available.

	:::caution pool limit
	If this pool has a maximum size and no objects are available to borrow, this will throw an error.
	:::

	@method Borrow
	@within ObjectPool<T>

	@return T -- The borrowed object.
	@return () -> () -- A function to dispose the object and return it to the pool.
]=]
function ObjectPool.Borrow<T>(self: ObjectPool<T>): (T, () -> ())
	-- Generate new object if necessary
	local object = (if (self.objects <= 0) then self:_generate() else table.remove(self._pool, 1)) :: T
	self.objects -= 1
	
	return object, function()
		self:Return(object)
	end
end

--[=[
	Returns an object to the pool.

	:::caution
	Make sure the object you pass to this function was borrowed from this pool.
	:::

	@method Return
	@within ObjectPool<T>
	
	@param object T -- The object to return.
]=]
function ObjectPool.Return<T>(self: ObjectPool<T>, object: T)
	if not self._managed[object] then
		error("Attempt to return object to ObjectPool that does not manage it")
	end

	table.insert(self._pool, object)
	self.objects += 1
end


return ObjectPool