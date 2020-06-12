-- guna
--
-- qualitiy of movement
-- e1: volume
-- e2: disintegration
-- e3: chaos
-- k2: multiverse-portal
-- k3:

sc = softcut

-- global params
local max_level_perc = 1
local level_perc = 1
local max_level_text = 0.0
local level_text = 0.0
local max_level_ton = 0.0
local level_ton = 0.0
local effect_level = 0.6
local max_effect_level = 0.6
local velocity = 0
local chaos = 0
local enc_1 = 0
local enc_2 = 0
local enc_3 = 0
local init_seed = 1234
local sequence_length = 8
local quantize_amounts = {2,4,8,16,32}
local samples = {}
local DEBUG = true

-- sample initialization
local samples = {
  {
    num =1,
    path=_path.code .. "nc02-rs/lib/nc02-perc.wav",
    start=0,
    len=9,
    history={},
    clocks={},
  },{
    num=2,
    path=_path.code .. "nc02-rs/lib/nc02-tonal.wav",
    start=15,
    len=9,
    sequences={},
    history={},
    clocks={},
  },{
    num=3,
    path=_path.code .. "nc02-rs/lib/nc02-texture.wav",
    start=30,
    len=4,
    sequences={},
    history={},
    clocks={},
  }
}

local percussion = {
  clap={slice={0.0,0.5},vel=0.5},
  rim={slice={1.0,1.2},vel=0.4},
  hat_1={slice={1.5,2.0},vel=0.4},
  hat_2={slice={2.0,2.1},vel=0.4},
  rim_2={slice={2.5,2.7},vel=0.6},
  rev={slice={3.0,3.84},vel=0.5},
  kick={slice={3.45,3.83},vel=1.0},
  effect_1={slice={3.95,4.16},vel=0.6},
  effect_2={slice={4.30,4.40},vel=0.6},
  effect_3={slice={4.60,4.90},vel=0.6},
  kicks={slice={4.90,5.60},vel=0.6},
  effect_4={slice={5.60,6.60},vel=0.6},
  effect_5={slice={6.7,7.0},vel=0.6},
  effect_6={slice={7.35,7.82},vel=0.6},
  effect_7={slice={7.830,8.70},vel=0.6}
}

local perc_sequence = {
  {s=1,n="kick"},{s=2,n=nil},{s=3,n="clap"},{s=4,n=nil},
  {s=5,n="kick"},{s=6,n="kick"},{s=7,n="effect_1"},{s=8,n="rim"}
}

-- utility functions
local function debug(msg)
  if DEBUG then
    print(msg)
  end
end

-- Print contents of `tbl`, with indentation.
-- `indent` sets the initial level of indentation.
-- credit to: https://gist.github.com/ripter/4270799
local function table_debug (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      debug(formatting)
      table_debug(v, indent+1)
    elseif type(v) == 'boolean' then
      debug(formatting .. tostring(v))
    else
      debug(formatting .. v)
    end
  end
end

local function get_sample_level(sample_num)
  if sample_num == 1 then
    return level_perc
  elseif sample_num == 2 then
    return level_ton
  else
    return level_text
  end
end

-- random generation functions
local function simple_flip(measure)
  if measure == nil then
    measure = 0.5
  end
  p = math.random(10) / 10
  if p <= measure then
    return true
  end
  return false
end

local function weighted_flip()
  p = math.random(10) / 10
  if p >= chaos then
    return false
  end
  return true
end

-- scale random assumes that 2 floats between 0 and 1 are passed in
-- and you want a random float between the two points
local function scale_random(scale_bottom, scale_top)
    if scale_bottom == 0 or scale_top == 0 then
      return math.random()
    end
    if scale_bottom > scale_top then
      sb = scale_top
      scale_top = scale_bottom
      scale_bottom = sb
    end
    sb = math.floor(scale_bottom *10)
    st = math.floor(scale_top*10)
    sr = math.random(sb, st) / 10
    return sr
end

-- random_engine takes a movement (-1 || 1) and utilizes the history number
-- to generate a random movement either above or below the number (movement). This is used
-- within bounds scale_bottom and scale_top. The random movement is a random number scaled
-- based on the current global chaos + the existing chaos seed generated on init or
-- changed by the amount of randomness introduced by the user. This is the magic function
local function random_engine(movement, history, scale_bottom, scale_top, center, polar)
  -- if centered and move towards center do nothing. tranquility
  if (movement < 0) and (history == center) then
    return history
  end

  -- rewrite history to flip polarity
  if polar and weighted_flip() then
    history = history * -1
  end

  -- movement towards center (tranqulity)
  if (movement < 0) then
    res = 0
    if (history < center) then
      -- shrink window based on chaos
      distance = center - history
      scaled_distance = history + (distance * chaos)
      res = scale_random(history,  scaled_distance)
    else
      -- shrink window based on chaos
      distance = history - center
      scaled_distance = center + (distance * chaos)
      res = scale_random(scaled_distance, history)
    end
    return res
  end

  -- movement away from center (entropy)
  res = 0
  direction = 0
  -- determine which direction is away from center, or utilize a simple coin flip to
  -- determine direction to move
  if center == scale_top then
    direction = -1
  elseif center == scale_bottom then
    direction = 1
  else
    if simple_flip() then
      direction = 1
    else
      direction = -1
    end
  end

  -- move towards the scale bottom with random scale depending on chaos
  if direction < 0 then
    distance = scale_bottom - history
    scaled_distance = history + (distance * chaos)
    res = scale_random(scaled_distance, history)
  end

  -- move towards top of scale with random scale depending on velocity
  if direction > 0 then
    distance = scale_top - history
    scaled_distance = history + (distance * chaos)
    res = scale_random(history, scaled_distance)
  end

  if history < center then
    -- shrink window based on chaos
    full_window = center - history
    scaled_window = math.floor(full_window * chaos)
    res = scale_random(scaled_window, center)
  else
    -- shrink window based on chaos
    full_window = history - center
    scaled_window = full_window * chaos
    res = scale_random(center, scaled_window)
  end

  return res
end

local rand_dur = {1,1/2,1/4,1/8,1/16}

local function get_duration()
  if weighted_flip() then
    return rand_dur[math.random(#rand_dur)]
  end
  if velocity < 0.15 then
    return 1
  elseif velocity < 0.30 then
    return 3/4
  elseif velocity < 0.45 then
    return 1/2
  elseif velocity < 0.60 then
    return 1/4
  elseif velocity < 0.75 then
    return 1/8
  else
    return 1/16
  end
end

-- sample effects
local function pan(voice, movement, pan_history)
  np = random_engine(movement, pan_history, -1, 1, 0, true)
  sc.pan(voice, np)
  return np
end

local function reverse_sample(voice, movement, reverse_state)
  r = reverse_state * -1
  sc.rate(voice, r)
  return r
end

local function delay(v)
  sc.enable(v,1)
  sc.buffer(v, 1)
  sc.position(v, 1)
  sc.loop_start(v, 1)
  sc.loop_end(v, 1.15)
  sc.loop(v, 1)
  sc.rate(v, 1)
  sc.level(v, effect_level)
  sc.rec_level(v, 0.5)
  sc.pre_level(v, 0.75)
  sc.rec(v, 1)
  sc.play(v, 1)
  sc.pan(v, 0)
  sc.pre_filter_fc(v, 9000)
  sc.pre_filter_dry(v, 0)
  sc.pre_filter_lp(v, 1)
  sc.pre_filter_rq(v, 0.8)
  sc.rate_slew_time(v, 0.3)
end

local function gate_chopper(voice)
  while true do
    clock.sync(get_duration())
    sc.level(voice, 0)
    clock.sync(get_duration())
    sc.level(voice, effect_level)
  end
end

local loop_num = 0
local function playback_fw(voice,position)
  if position >= 38.9 then
    sc.rate(voice, -1)
  end
  if position == 30 and loop_num == 0 then
    loop_num = loop_num + 1
  end
  if position == 30 and loop_num > 0 then
    sc.rate(voice, 1)
  end
end

-- sequencer code
local function sample_one_shot(voice, sample_num, slice_start, slice_end)
    sc.position(voice, slice_start)
    sc.loop(voice, 0)
    sc.loop_start(voice, slice_start)
    sc.loop_end(voice, slice_end)
    sc.level(voice, get_sample_level(sample_num))
    sc.play(voice, 1)
end

local beat_divisors = {8,12,16,24}

local function beat_repeat(voice, sample_num, slice_start, slice_end, repeats)
  for i=1,repeats,1 do
    redraw(true)
    clock.sync(1/repeats)
    sample_one_shot(voice, sample_num, slice_start, slice_end)
  end
end

local function play_step(voice, sample_num, slice_start, slice_end, duration)
  if weighted_flip() and simple_flip() then
    beat_repeat(voice, sample_num, slice_start, slice_end, beat_divisors[math.random(#beat_divisors)])
  end
  sample_one_shot(voice, sample_num, slice_start, slice_end, duration)
end

local function percussion_sequencer()
  b = 1
  v = 1
  while true do
    d = get_duration()
    clock.sync(d)
    s = perc_sequence[b]
    if not (s == nil or s.n == nil or s.n == "") then
      p = percussion[s.n]
      play_step(v, 1, p.slice[1], p.slice[2], d)
      v = v + 1
      if v > 2 then v = 1 end
    elseif weighted_flip() then
      p = percussion[math.random(#percussion)]
      play_step(v, 1, p.slice[1], p.slice[2], d)
      v = v + 1
      if v > 2 then v = 2 end
    end
    b = b + d
    if b >= 4 then b = 1 end
  end
end

local function init_samples()
  perc_voice = samples[1]
  sc.buffer_read_mono(perc_voice.path,0,perc_voice.start,-1,1,1)
  pv = 1
  c = clock.run(percussion_sequencer)
  perc_voice.clocks[#perc_voice.clocks+1] = c

  tonal = samples[2]
  sc.buffer_read_mono(tonal.path,0,tonal.start,-1,1,1)
  sc.position(3,tonal.start)
  sc.loop_start(3,tonal.start)
  sc.loop_end(3,tonal.start+tonal.len)
  sc.loop(3,1)
  sc.rate(3,1)
  sc.level(3,get_sample_level(tonal.num))
  sc.play(3,1)

  texture = samples[3]
  sc.buffer_read_mono(texture.path,0,texture.start,-1,1,1)
  sc.buffer_read_mono(texture.path,0,texture.start,-1,1,1)
  sc.position(4,texture.start)
  sc.loop_start(4,texture.start)
  sc.loop_end(4,texture.start+texture.len)
  sc.loop(4,1)
  sc.rate(4,1)
  sc.level(4,get_sample_level(texture.num))
  sc.play(4,1)

  -- sc.level_cut_cut(v,5,0.5)
  -- start_echo_voice(5)
end

local function multiverse_portal()
  -- upon activation of the portal voices should swap sequencers with each other
  -- this will create the illusion that the voices were always swapped
  -- should be a linear movement so a user has 3 universes to teleport between
  -- simply increment buffer positions to achieve the effect
end

local frame = 0
local frame_reset = 240
local frame_dir = 1
local counter = 1

-- script start
function init()
  sc.buffer_clear()
  math.randomseed(init_seed)
  for v=0,6,1 do
    sc.enable(v,1)
    sc.buffer(v,1)
    sc.rate(v,1)
    sc.level(v,1)
  end
  init_samples()
  -- screen metro
  sm = metro.init()
  sm.time = 1/16
  sm.event = function()
    redraw(false)
  end
  sm:start()
end

local function graphic_loop(f)
  rad = 0.2 * f
  screen.move(65,30)
  for i=0,360,10 do
    x = (rad*0.7)*math.sin(i) + math.random()
    y = (rad*0.7)*math.cos(i) + math.random()
    screen.pixel(x+65, y+30)
  end
  for i=0,360,10 do
    x = (rad*0.68)*math.sin(i) + math.random()
    y = (rad*0.68)*math.cos(i) + math.random()
    screen.line(x+65, y+30)
  end
  -- screen.circle(65,30,rad)
  screen.stroke()
  screen.update()
end

function redraw(glitch)
  if glitch then
    screen.clear()
    cg = math.random((frame_reset - 20),frame_reset)
    if cg < 0 then cg = 0 end
    graphic_loop(cg)
    goto done
  end
  screen.clear()
  if frame then
    frame = frame + frame_dir
  end
  graphic_loop(frame)
  if frame == frame_reset then
    frame_dir = frame_dir * -1
  end
  if frame == 0 then
    frame_dir = frame_dir * -1
  end
  ::done::
end

-- encoder functions
function key(k,z)
  -- shuffle
  if k == 2 then
    if z == 1 then
      debug("multiverse flip")
    end
  end
  -- draw
  if k == 3 then
    if z == 1 then
      print("button pressed")
    end
  end
end

function enc(n,d)
  -- volume encoder
  if n == 1 then
    level_perc = util.clamp(level_perc+d/100,0,max_level_perc)
    level_ton = util.clamp(level_ton+d/100,0,max_level_ton)
    level_text = util.clamp(level_text+d/100,0,max_level_text)
    effect_level = util.clamp(effect_level+d/100, 0, max_effect_level)
    for _, s in pairs(samples) do
      if s.num == 1 then
        for _, v in pairs(s.voices) do
          sc.level(v, level_perc)
        end
      elseif s.num == 2 then
        for _, v in pairs(s.voices) do
          sc.level(v, level_ton)
        end
      else
        for _, v in pairs(s.voices) do
          sc.level(v, level_text)
        end
      end
    end
    sc.level(5, effect_level)
  end
  -- velocity: tendency towards faster cycles -- deconstruction
  if n == 2 then
    velocity = util.clamp(velocity+d/100,0.1,1)
    vn = 1 - velocity
    for i=1,6 do
      sc.fade_time(i,vn)
      sc.level_slew_time(i,vn)
      sc.rate_slew_time(i,vn)
    end
  end
  -- chaos: tendency towards more random events -- reshaping
  if n == 3 then
    chaos = util.clamp(chaos+d/100,0,1)
  end
end
