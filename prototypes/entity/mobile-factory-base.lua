-- THE BASE MOBILE FACTORY PROTOTYPE --

-- Create Mobile Factory entity (Copy from base tank) --
local mf = table.deepcopy(data.raw.car.tank)
mf.name = "MobileFactory"
mf.order = "a"
mf.equipment_grid = "MFEquipmentGrid"
mf.minable = {mining_time = 1.5, result = "MobileFactory"}
mf.inventory_size = 10
mf.max_health = 2500
mf.consumption = "700KW"
mf.weight = 25000
mf.braking_power = "600kW"
mf.rotation_speed = 0.30 / 60
mf.guns = {"mfTank-machine-gun"}
mf.collision_box = {{-1.4, -2.5}, {1.1, 1.7}}
mf.selection_box = mf.collision_box
mf.animation =
{
	layers =
	{
		{
			priority = "low",
			width = 269,
			height = 212,
			frame_count = 2,
			direction_count = 64,
			shift = util.by_pixel(-4.75, -10),
			animation_speed = 8,
			max_advance = 1,
			scale = 0.7,
			stripes =
			{
				{
				filename = "__base__/graphics/entity/tank/hr-tank-base-1.png",
				width_in_frames = 2,
				height_in_frames = 16
				},
				{
				filename = "__base__/graphics/entity/tank/hr-tank-base-2.png",
				width_in_frames = 2,
				height_in_frames = 16
				},
				{
				filename = "__base__/graphics/entity/tank/hr-tank-base-3.png",
				width_in_frames = 2,
				height_in_frames = 16
				},
				{
				filename = "__base__/graphics/entity/tank/hr-tank-base-4.png",
				width_in_frames = 2,
				height_in_frames = 16
				}
			}
		},
		{
		priority = "low",
		width = 207,
		height = 166,
		frame_count = 2,
		direction_count = 64,
		shift = util.by_pixel(-4.75, -21),
		max_advance = 1,
		line_length = 2,
		stripes = util.multiplystripes(2,
		{
		  {
			filename = "__base__/graphics/entity/tank/hr-tank-base-mask-1.png",
			width_in_frames = 1,
			height_in_frames = 22
		  },
		  {
			filename = "__base__/graphics/entity/tank/hr-tank-base-mask-2.png",
			width_in_frames = 1,
			height_in_frames = 22
		  },
		  {
			filename = "__base__/graphics/entity/tank/hr-tank-base-mask-3.png",
			width_in_frames = 1,
			height_in_frames = 20
		  }
		}),
		scale = 0.7
		},
		{
			priority = "low",
			width = 301,
			height = 194,
			frame_count = 2,
			draw_as_shadow = true,
			direction_count = 64,
			shift = util.by_pixel(17.75, 7),
			max_advance = 1,
			stripes = util.multiplystripes(2,
			{
			 {
			  filename = "__base__/graphics/entity/tank/hr-tank-base-shadow-1.png",
			  width_in_frames = 1,
			  height_in_frames = 16
			 },
			 {
			  filename = "__base__/graphics/entity/tank/hr-tank-base-shadow-2.png",
			  width_in_frames = 1,
			  height_in_frames = 16
			 },
			 {
			  filename = "__base__/graphics/entity/tank/hr-tank-base-shadow-3.png",
			  width_in_frames = 1,
			  height_in_frames = 16
			 },
			 {
			  filename = "__base__/graphics/entity/tank/hr-tank-base-shadow-4.png",
			  width_in_frames = 1,
			  height_in_frames = 16
			 }
			}),
			scale = 0.7
		}
	}
}
mf.turret_animation =
{
	layers =
	{
		{
			filename = "__base__/graphics/entity/tank/hr-tank-turret.png",
			priority = "low",
			line_length = 8,
			width = 179,
			height = 132,
			frame_count = 1,
			direction_count = 64,
			shift = util.by_pixel(-4.75, -50),
			animation_speed = 8,
			scale = 0.7
		},
		{
			filename = "__base__/graphics/entity/tank/hr-tank-turret-mask.png",
            priority = "low",
            line_length = 8,
            width = 72,
            height = 66,
            frame_count = 1,
            direction_count = 64,
            shift = util.by_pixel(-5, -50),
            scale = 0.7
		},
		{
			filename = "__base__/graphics/entity/tank/hr-tank-turret-shadow.png",
            priority = "low",
            line_length = 8,
            width = 193,
            height = 134,
            frame_count = 1,
            draw_as_shadow = true,
            direction_count = 64,
            shift = util.by_pixel(51.25, 6.5),
            scale = 0.7
		}
	}
}
data:extend{mf}

-- Create Mobile Factory Item --
local mfI = {}
mfI.type = "item-with-entity-data"
mfI.name = "MobileFactory"
mfI.icon = "__Mobile_Factory__/graphics/mobileFactory/tank.png"
mfI.icon_size = 32
mfI.place_result = "MobileFactory"
mfI.subgroup = "MobileFactory"
mfI.order = "a"
mfI.stack_size = 1
data:extend{mfI}

-- Create the Mobile Factory Recipe --
local mfR = {}
mfR.type = "recipe"
mfR.name = "MobileFactory"
mfR.energy_required = 10
mfR.ingredients =
    {
      {"copper-plate", 10},
      {"iron-plate", 10}
    }
mfR.result = "MobileFactory"
data:extend{mfR}

function createNewMF(name, color, size, order, icon)
	local nMFE = table.deepcopy(data.raw.car.MobileFactory)
	nMFE.name = name
	nMFE.order = order
	nMFE.minable = {mining_time = 1.5, result = name}
	nMFE.animation.layers[2].tint = color
	nMFE.turret_animation.layers[2].tint = color
	nMFE.animation.layers[1].scale = size
	nMFE.turret_animation.layers[1].scale = size
	nMFE.animation.layers[2].scale = size
	nMFE.turret_animation.layers[2].scale = size
	nMFE.animation.layers[3].scale = size
	nMFE.turret_animation.layers[3].scale = size
	nMFE.turret_animation.layers[1].shift = util.by_pixel(-4.75, -50/0.7*size)
	nMFE.turret_animation.layers[2].shift = util.by_pixel(-5, -50/0.7*size)
	nMFE.turret_animation.layers[3].shift = util.by_pixel(51.25, 6.5/0.7*size)
	nMFE.collision_box = {{-1.4/0.7*size, -2.5/0.7*size}, {1.1/0.7*size, 1.7/0.7*size}}
	nMFE.selection_box = nMFE.collision_box
	data:extend{nMFE}
	
	local nMFI = table.deepcopy(data.raw["item-with-entity-data"].MobileFactory)
	nMFI.name = name
	nMFI.order = order
	nMFI.icon = icon
	nMFI.place_result = name
	data:extend{nMFI}
	
	local nMFR = table.deepcopy(data.raw.recipe.MobileFactory)
	nMFR.name = name
	nMFR.result = name
	nMFR.enabled = false
	data:extend{nMFR}
	
	local nMFT = {}
	nMFT.name = name
	nMFT.type = "technology"
	nMFT.icon = icon
	nMFT.icon_size = 32
	nMFT.unit = {
		count=1000,
		time=2,
		ingredients={
			{"DimensionalSample", 1}
		}
	}
	nMFT.prerequisites = {"DimensionalCrystal"}
	nMFT.effects = {{type="unlock-recipe", recipe=name}}
	data:extend{nMFT}
end