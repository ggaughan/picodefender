pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- pico defender
-- ggaughan, 2021
-- remake of the williams classic

debug = true
debug_test = debug  -- 1 of each enemy per wave

human=7
lander=9
mutant=25
baiter=41
bomber=57
pod=73
swarmer=89
mine=105
bullet=24

waves = {
 {--1
	 c=1, 
		landers=15,
		bombers=0,
		pods=0,
	},
 {--2
	 c=3, 
		landers=20,
		bombers=3,
		pods=1,
	},
 {--3
	 c=8, 
		landers=20,
		bombers=4,
		pods=3,
	},
 {--4
	 c=9, 
		landers=20,
		bombers=5,
		pods=4,
	},
 {--5
	 c=10,
		landers=20,
		bombers=5,
		pods=4,
	},
 {--6
	 c=4,
		landers=20,
		bombers=5,
		pods=4,
	},
 {--7
	 c=0,
		landers=20,
		bombers=5,
		pods=4,
	}
}


ww = 128 * 9
cx = 128 * 4
ocx = cx

inertia_py = 0.95
inertia_cx = 0.99


hc = 128/4
hudy=12  -- = hudh
hudw=hc*2
hwr = ww/hudw
hhr = (128-4 - hudy)/hudy + 1
lmin = 3
lmax = 56

max_speed = 2
thrust = 0.4
vert_accel = 0.6
max_vert_speed = max_speed/2
max_h_speed_factor = max_speed/48

laser_expire = 1
laser_size = 30  -- see rate
laser_rate=8
laser_max_length = 100  -- cap
laser_min_length = 8  -- show something immediately
min_laser_speed = 0.2 -- e.g. static ship, move away still
laser_speed = 1.8
laser_min_effective_age = 0.03  -- delay so it can be seen before being effective
laser_inertia = 0.999

lander_speed = 0.3
mutant_speed = 0.6
bullet_expire = 1.5
bullet_speed = 1.6

particle_expire = 1
particle_speed = 0.8
--enemy_explode_size = 32

player_die_expire = 3
old_particle = 1
enemy_die_expire = 1

human_speed = 0.02
target_x_epsilon = 1
target_y_epsilon = 3
capture_targetted = 1
capture_lifted = 2
capture_dropped = 3
gravity_speed = 1

wave_progression = 15  -- seconds
wave_reset = 2  -- seconds

function _init()
	w = {}  -- ground + stars
	sw = {} -- ground summary
	stars = {}
	actors = {}
	particles = {}

	cx = 128 * 4
 cdx = 0
 canim = 0
 canim_dx = 0

	build_world()
	
	pl = {
		x=cx+20,  
		y=64,
		
		w=5,
		h=3,
		
		lives=3,
		score=0,
		bombs=3,
		
		facing=1,
		dx=0,
		dy=0,
		thrusting=false,
	 thrusting_t=0,
	 thrusting_spr=0,
	 
	 hit=nil,
	 c=7,  -- for explosion
	}

	if false then	
		for i=1,300 do
			add_pl_score(32000)
		end
		add_pl_score(1234)
	end
	
	lasers = {}

	add_stars()
	
	iwave=0
	humans=0  -- topped up by load_wave
	load_wave()
	-- todo wrap iwave display to 2 digits (100 and 200 show as 0 when completed) 
	--      then actually wrap at 255 with special wave 0
	add_humans()
	add_enemies()

	-- palette rotate	
	pt = time()
	cc = 1
	
	_draw = _draw_wave
end



-->8
--update

function _update60()
 local t=time()

 update_particles()  -- could include player dying

	if pl.hit == nil then
	 if btnp(⬅️) then
	  -- todo avoid repeat with re-press
		 pl.facing = -1*pl.facing
		 -- start reverse animation
		 canim=80
		 canim_dx=pl.facing
	  cdx = cdx * 0.5
		end
	 if btn(➡️) then
	  cdx = min(cdx+thrust,max_speed)
	 end
	 if btn(⬆️) then
	  pl.dy = pl.dy-vert_accel
	  if (pl.dy < -max_vert_speed) pl.dy=-max_vert_speed
	 end
	 if btn(⬇️) then
	  pl.dy = pl.dy+vert_accel
	  if (pl.dy > max_vert_speed) pl.dy=max_vert_speed
	 end
	 
	
	 if btnp(❎) then
			-- fire laser
			-- todo limit
	  local x = pl.x
	 	if pl.facing > 0 then
	 		x = x+8 + 1+1+1
	 	end
	 	add(lasers, {x - 2,pl.y+5,pl.facing,time(),max(cdx, min_laser_speed)})
	 end
	 -- update any existing lasers
	 -- todo move to update_lasers()
	 for laser in all(lasers) do
	 	if t-laser[4] > laser_expire then
	 		del(lasers,laser)
	 	end
	 	-- todo wrap?
	 	laser[1] += laser[5]*laser[3] * laser_speed
	 	laser[5] *= laser_inertia
	 end
	 --if btnp(🅾️) then -- z
	 	-- smart bomb - kill all enemies
	 --end
	 
	 pl.dy *= inertia_py
	 pl.y += pl.dy 
	 
	 cdx *= inertia_cx
	 cx += cdx * pl.facing
	 pl.x += cdx * pl.facing
	
		-- player thrust/decay
		-- in screen space to handle any wrapping
		local x = wxtoc(pl.x)
	 if pl.facing == 1 then
	 	if x < 40 then
			 if btn(➡️) then
		 		pl.x += cdx * max_h_speed_factor
		 	end
	 	end
	 	if x > 20 then
			 if not btn(➡️) then
			  -- fall back
			 	pl.x -= thrust/2
			 end
		 end
	 else
	 	if x > 80 then
			 if btn(➡️) then
		 		pl.x -= cdx * max_h_speed_factor
		 	end
	 	end
	 	if x < 100 then -- assumes <128, if not we're off camera but will move
	 		if not btn(➡️) then
	 			-- fall back
	 			pl.x += thrust/2
	 		end
	 	end
	 end
		if btn(➡️) then
			if not pl.thrusting then
			 pl.thrusting=true
	 	end
		else 
	 	pl.thrusting=false
		end
	 if t-pl.thrusting_t > 0.05 then
			pl.thrusting_spr = (pl.thrusting_spr+1) % 4
			pl.thrusting_t = t
		end
		
	 update_enemies()  -- checks for player hit
	  
	 -- camera wrap
	 if cx<0 then
	 	cx = ww
	 elseif cx > ww then
	  cx = 0
	 end
	 
	 -- player wrap
	 -- todo retain screen offset pos!
	 if pl.x<0 then
	 	pl.x = ww
	 elseif pl.x > ww then
	  pl.x = 0
	 end
	 
	 if pl.y < hudy then
	 	pl.y = hudy
	 	pl.dy = 0
	 elseif pl.y > 120 then
	  pl.y = 120
	 	pl.dy = 0
	 end
	 
	 update_wave()
 
	else
	 -- player dying 
	 -- or pausing between waves
	 -- either way, both fixed via draw_player timeout
	end
end

function update_enemies()
	local t = time()
	for e in all(actors) do
		-- check if hit by laser
	 for laser in all(lasers) do 	
	  if not e.hit then
				--local actual_age = (t-laser[4]) --/ laser_expire
				local age = (t-laser[4])/laser_expire
				local x,y = laser[1], laser[2]
			 -- todo include wrap at end
			 --      or cut short draw!
				--if actual_age > laser_min_effective_age then
				if (age * laser_size * laser_rate) > abs(e.x-x) then
				 -- todo precalc half widths			
				 -- todo include wrap at end
				 -- todo maybe cut off at screen/camera
					if y > (e.y+e.dy+(8-e.h)/2) and y < (e.y+e.dy+8-(e.h/2)) then
						-- note: quick check against max and assume width == 8 (and player can't be on enemy)
						if (laser[3] > 0 and x < e.x and x+laser_max_length > e.x) or (laser[3] < 0 and x > e.x and x-laser_max_length < e.x) then
							-- todo refine based on laser age and actual width and e.dx? - no need, light speed!
							--printh("laser hit "..e.x)
				 		e.hit = t
						 kill_actor(e, laser)
						end			
					end 	
				-- else just fired - give it chance to be seen
				end
		 end		
		end
		
		if not e.hit then  
			-- check if hit player
		 -- todo include wrap at end
			local x=(e.x+e.dx) - pl.x 
			local y=(e.y+e.dy) - pl.y
			if e.k ~= human then
				if (abs(ceil(x)) < (e.w+pl.w) and
						 (abs(ceil(y))) < (e.h+pl.h))
				then
		 		e.hit = t
				 kill_player(e)
				end
			end
			
			if not e.hit then
		  e.x += e.dx
		  -- todo % simplify
			 if e.x<0 then
			 	e.x = ww 
			 elseif e.x > ww then
			  e.x = 0
			 end
		  e.y += e.dy
				
				-- todo move to ai/behaviour routine
				if e.k == lander then  
					if e.target ~= nil then
						-- todo wrap
					 if e.target.capture == capture_lifted then
					 	--printh("lifting "..e.x.." "..e.target.x)
					 	e.target.x = e.x + 1
					 	e.target.y = e.y + 6
					 	-- todo dx/dy?
					 	if e.y < hudy+1 then
					 		printh("convert to mutant"..e.x)
					 		kill_actor(e.target,nil,false)  -- kill human silently
					 		-- possibly now nullspace
					 		--no need: already decremented and reset_enemies will notice: wave.landers -= 1  -- spawn 1 less
					 		e.k = mutant
					 		--note: reset_enemies will do this: wave.mutants += 1  -- note: reset_enemies won't do this
					 		e.lazy = 0  -- todo or remove altogether?
					 		-- todo inc speed
					 	end
					 elseif e.target.capture == capture_targetted and abs(e.x - e.target.x) < target_x_epsilon and abs(e.y - e.target.y) < target_y_epsilon then
					 	-- here!
					 	printh("capturing! "..e.x.." "..e.target.x)
					 	e.dy = -lander_speed/2
					 	e.dx = 0  -- straight up
							e.target.capture = capture_lifted
							e.target.dy = gravity_speed  -- for if/when dropped
					 elseif e.x < e.target.x then
						 e.dx = lander_speed
		 				if e.y < hudy + 90 and e.dy < 0 then
								e.dy *= -1
							end
						else
						 e.dx = -lander_speed
		 				if e.y < hudy + 90 and e.dy < 0 then
								e.dy *= -1
							end
					 end			
 				else
 					-- will bounce up and down
						if rnd() < 0.2 then
							e.dx = lander_speed/4
						elseif rnd() < 0.2 then
							e.dx = -lander_speed/4
						elseif rnd() < 0.2 then
							e.dx = 0
						end
					end				
					-- attack
					-- todo wrap?
					if abs(e.x - pl.x) < 128 then
						if rnd() < 0.002 then
							b=add_bullet(e.x, e.y)  -- todo pass weak=true
						end
					end				
				elseif e.k == mutant then
					-- ai
					-- todo remove lazy now? use for other type
					if abs(e.x - pl.x) < (rnd(256) - e.lazy) then
					 if e.x < pl.x then
						 e.dx = mutant_speed
						else
						 e.dx = -mutant_speed
					 end
					 
					 if e.y < hudy + rnd(20) and e.y < pl.y and e.dy<0 then
					 	e.dy *= -1
					 elseif e.y > 120 - rnd(20) and e.y > pl.y and e.dy>0 then
					 	e.dy *= -1
					 end
					end

					-- attack
					-- todo wrap?
					if abs(e.x - pl.x) < 128 then
						if rnd() < 0.006 then
							b=add_bullet(e.x, e.y)
						end
					end				
				elseif e.k == bullet then
			 	if t-e.t > bullet_expire then
			 		del(actors,e)
			 	end
			 elseif e.k == human then
			  -- don't bounce - gravity
					if e.y > 120 then
						e.y = 120 
						e.dy = 0 
					end 	 
				-- else other types
				end
				
				-- general bounce to stop y out of bounds
				if e.y < hudy +1 then
					e.y = hudy +1
					e.dy *= -1
				elseif e.y > 120 then
					e.y = 120 
					e.dy *= -1
				end 
				
			-- else hit and no more
			end
		-- else hit and no more
		end
	end
end

function update_particles()
	local t = time()
	for e in all(particles) do
 	if t-e.t > e.expire then
 		del(particles,e)
 	else
	  e.y += e.dy  
	  if e.y < hudy or e.y > 127 then
	 		del(particles,e)
	  else
		  e.x += e.dx
		  -- todo % simplify
			 if e.x<0 then
			 	e.x = ww 
			 elseif e.x > ww then
			  e.x = 0
			 end
			 -- todo opt: cull if off-screen - though short-lived
			end
	 end
	end
end

function update_wave()
	local t=time()
	local age = t-wave.t_chunk
	if age > wave_progression then
  wave.t_chunk = t  -- reset
		if humans > 0 then
		 printh("humans at"..t)
			add_humans()
		end
		if wave.landers > 0 or wave.mutants > 0 then	 
		 printh("more at"..t)
			add_enemies()
		end
	end
end

-->8
--draw

function wtos(wx,wy)
	--x=hc + ((ocx + wx)\hwr) % hudw
	x=hc + ((ocx + wx - cx)\hwr) % hudw
	y=wy\hhr
	return x,y
end

function wxtoc(wx)
 -- note: we wrap here 
	x = wx - cx
	if cx + 128 > ww then
		if wx < (128 - (ww-cx)) then
			x = (wx + ww) - cx
		end
	end
	return x
end

function draw_score(v)
 local i=6
 repeat
  local t=v>>>1
  -- todo map to font
  print((t%0x0.0005<<17)+(v<<16&1),i*4,6,5)
  v=t/5
 	i-=1
 until v==0
end

function add_pl_score(v)
 assert(v<32767)  
	pl.score += v >> 16
end

function draw_hud()
 local hdc = hudw/9
 
 -- ground
	for x = 0,hudw-1 do
		i = (x + (ocx + 128 + cx)\hwr) % hudw + 1
		pset(hc+x,hudy - (sw[i]), 4)
	end
	
	-- player
 local	sx,sy = wtos(pl.x, pl.y)
	pset(sx,sy, 7)

	-- enemies
	for e in all(actors) do
	 -- todo skip if bullet?
	 --if e.k~=bullet then
		sx,sy = wtos(e.x, e.y)
		pset(sx,sy, e.c)
		--end
	end

	-- scanner box 
	rect(hc,0, hc+hudw,hudy, wave.c)
	line(0,hudy,127,hudy, wave.c)
	line(hc+hdc*4-1,0, hc+hdc*5+1,0, 7)
	pset(hc+hdc*4-1,1, 7)
	pset(hc+hdc*5+1,1, 7)
	line(hc+hdc*4-1,hudy, hc+hdc*5+1,hudy, 7)
	pset(hc+hdc*4-1,hudy-1, 7)
 pset(hc+hdc*5+1,hudy-1, 7)
 
 draw_score(pl.score)
 
 for i=1,min(pl.bombs,3) do
 	spr(4,25,-7+i*4)
 end
 for i=1,min(pl.lives,5) do
 	spr(5,(i-1)*5,-4)
 end
end

function draw_player()
	local t=time()
	-- draw_lasers
	for laser in all(lasers) do
		--printh(tostr(laser))
		local x,y = wxtoc(laser[1]), laser[2]
		local age = (t-laser[4]) / laser_expire
		local mdx,mdy=1/8,0
		tline(
		 x,
			y,
			x+min(
			  		max((age * laser_size) * laser_rate, 
    	  				laser_min_length
				  		  ) 
 		  		, 
	 			 	laser_max_length 
		 		 ) * laser[3], 
  	y, 
	 	0,0,
	 	mdx,mdy
		)
	end

	if pl.hit ~= nil then
		local age = (t-pl.hit)
		--printh("player dying "..age)
		if age > player_die_expire then
			pl.hit = nil	
 		reset_enemies()  -- hide and respawn enemies after a period...
			--printh("player rebirth "..age)
		end
	else
		local x = wxtoc(pl.x)
		spr(2, x, pl.y, 1,1, pl.facing==-1)
		if pl.thrusting then
			spr(32+pl.thrusting_spr, x-(8*pl.facing), pl.y, 1,1, pl.facing==-1)
		else
			spr(48+pl.thrusting_spr, x-(8*pl.facing), pl.y, 1,1, pl.facing==-1)
		end
	end
end

function draw_enemies()
	local t=time()
	for e in all(actors) do
		if e.hit ~= nil then
			local age = (t-e.hit)
			-- todo if dying? cleared elsewhere?
			if age > enemy_die_expire then
				e.hit = nil
				--printh("enemy birthed "..age)
			else
				--printh("enemy birthing "..age)	
			end
		else
			local x,y = wxtoc(e.x), e.y
			local fx = (e.k==human and e.dx>0)

 		spr(e.k, x, y, 1,1, fx)	
		 -- todo animate?
		end
	end
end

function draw_particles()
	local t=time()
	for e in all(particles) do
		local x,y = wxtoc(e.x), e.y
		local c = e.c
		local age = (t-e.t)
		if (age > old_particle) c = 9
		pset(x, y, c)	
	end
end

function draw_stars()
	for star in all(stars) do
		local x = star[1] - (cx/star[3])  -- -cx for screen; /star[3] for move-delay
		local col = 5
		if cx + 128 > ww then
			if star[1]-(cx/star[3]) < (128 - (ww-cx)) then
 			x = (star[1]+(ww/star[3])) - (cx/star[3])
				col = 14  --new or fade depending on dir
			end

			if star[1] > ((ww/star[3]) - 128) then
 			if col == 14 then
 				--all! how!? 
 				--col = 11  --new+fade?
 			else
					col = 12  --fade or new depending on dir
				end
 		end
		end
		
		if (col ~= 5) col = 5
		
		pset(x, star[2], col)
	end
end

function animate_camera()
 -- e.g. player reversing
	-- assumes canim>0
	canim -= 1
	cx += canim_dx
	pl.x -= canim_dx

 -- camera wrap
 if cx<0 then
 	cx = ww
 elseif cx > ww then
  cx = 0
 end
	
	-- in screen space to handle any wrapping
	local x = wxtoc(pl.x)
	if x < 20 then
 	pl.x = (cx + 20) % ww
 	canim = 0
	elseif x > 100 then  -- assumes <128, if not we're off camera and will jump
	 pl.x = (cx + 100) % ww
	 canim = 0
	end
	-- note: player wrap done via %	
end

function _draw_game_over()
 cls()
 
	draw_hud()

	draw_stars()

	draw_hud()

	-- draw_ground	
	for x = 0,127 do
		i = ((ceil(cx+x))%ww) + 1
		--printh(i)
		pset(x,127 - w[i][1], 4)
	end

	draw_enemies()
	draw_particles()

	-- never expire! draw_player()  -- needed to expire

	-- todo 3d text?
	print("game over", 45, hudy+40, 5)

	if pl.hit == nil then
	 -- todo hi-scores then re-init and repoint _draw/_update60
	end
end

function _draw_end_wave()
 cls()
 
	draw_hud()
	draw_player()  -- needed to expire

	-- todo 3d text?
	rectfill(0, hudy+1,127,127, 0)
	print("attack wave "..(iwave+1), 40, hudy+20, 5)
	print("completed", 46, hudy+28, 5)
	print("bonus x "..100*min(iwave+1,5), 43, hudy+48, 5)
	for h=1,humans do
		spr(human,33+h*5, hudy+56)
	end

	if pl.hit == nil then
		-- note: already increased score
	 cdx = 0 -- freeze  -- todo move into load_wave?
	 -- todo reset cx?
		pl.x=cx+20
		pl.y=64
		pl.facing=1  -- todo need camera move?
		pl.dx=0
		pl.dy=0
		pl.thrusting=false
	 
		iwave += 1
		load_wave()
		-- prime the spawning
		local t=time()
		wave.t_chunk = t - wave_progression + wave_reset  -- reset

		_draw = _draw_wave
	end
end

function _draw_wave()
 cls()
 
 local t=time()
 
 if t-pt > 0.2 then
  cc = (cc%15) + 1
	 pal(5, cc) -- todo true?
	 pt = t
	end
 
 if (canim > 0) animate_camera()

	draw_stars()

	draw_hud()

	-- draw_ground	
	for x = 0,127 do
		i = ((ceil(cx+x))%ww) + 1
		--printh(i)
		pset(x,127 - w[i][1], 4)
	end

	draw_enemies()
	draw_particles()

	draw_player()
		
	if debug then
		print(cx,1,120,1)
		print(pl.x,48,120)
		--print(cdx,1,6)
		if cx + 128 > ww then
			print("★",1,13)
		end
		print(#actors,100,0)
		print(#particles,100,6)
		assert(humans<=10)
		print(humans,120,0)
		print(iwave+1,120,6)
	end

end


-->8
--build world

function build_world()
 local l = 10
 local ldy = 1
 local ls = nil
 local ll = nil
	for i = 1,ww do
	 local r = rnd()
	 
	 if r > 0.8 then
	 	ldy = 1
	 elseif r < 0.2 then
	  ldy = -1
	 else
	 	if r > 0.79 or r < 0.21 then
		 	ldy = -1 * ldy
		 end
	 end
	 
	 if ldy > 0 then
	  if l <= lmax then
   	l += 1
		 else
		 	ldy = -1
		 end
	 elseif ldy < 0 then
	 	if l >= lmin then
 	  l -= 1	
		 else 
		  ldy = 1
		 end
	 end
	 
	 if i % hwr == 0 then
   ls = ll
   ll = ceil(l/hhr)  -- pre-calc
   if ls and abs(ll - ls) > 1 then
    -- patch any holes
   	if ll - ls < 0 then
	   	ll = ll + 1
   	else
	   	ll = ll - 1
   	end
   end
	 	sw[i \ hwr] = ll
	 end

	 -- todo make level ends meet!	 
	 
		w[i] = {l}
	end
end

function add_stars()
	for s = 1,100 do
		add(stars, {
			rnd(ww), rnd(127-hudy-lmax-8)+hudy, 
			rnd(2)+10  -- parallax depth
		})
	end
end

function make_actor(k, x, y, hit)
 a={
 	k=k,
 	c=11,
  x=x,
  y=y,
  dx=0,
  dy=0,
  frame=0,
  t=0,
  frames=1,
  w=8,
  h=8,  
  
  lazy=0,
  hit=hit,
  score=0,
 }
	add(actors,a)
	return a
end

function add_bullet(x, y)
 t=time()
	b=make_actor(bullet,x,y)
	-- todo aim at pl!
	b.dx = ((pl.x - b.x)/128) * bullet_speed
	b.dy = ((pl.y - b.y)/128) * bullet_speed
	b.t = t
	b.w = 1
	b.h = 1
	b.c = 6
	return b
end

sp = {
 {-1.2,-1},
 {-0.8,-1},
 
 { 0,  -1},
 { 0,  -1},
 
 { 0.8,-1},
 { 1.2,-1},

 { 1,   0},
 { 1,   0},
 
 {-1.2, 1},
 {-0.8, 1},

 { 0,   1},
 { 0,   1},
 
 { 0.8, 1},
 { 1.2, 1},
 
 {-1,   0}, 
 {-1,   0}, 
}
function add_explosion(e, reverse, speed, expire)
	reverse = reverse or false
	speed = speed or particle_speed
	expire = expire or particle_expire
	local t=time()
	local f=0
 for i=1,16 do
  -- todo make some faster
  local x,y=e.x,e.y
  local s=speed
  local d=sp[i]
  if d[1] == 0 or d[2] == 0 then
			if (f==0) s=particle_speed*0.8
  	f = 1-f  --prevent for next one
  end
  if reverse then
  	x+=d[1]*60
  	y+=d[2]*60
  	d[1], d[2] = -1*d[1], -1*d[2]
  end
		add(particles,{
			x=x,y=y,
			dx=d[1]*s,dy=d[2]*s,
			c=e.c, t=t, expire=expire,
		})
	end
end

function kill_actor(e, laser, explode)
	if (explode == nil) explode = true
	print("explode "..tostr(explode))
 if explode then
		if not(e.k == bullet or e.k == mine) then
		 add_explosion(e)
	 	if laser then
	 		del(lasers,laser)  -- i.e. allow to hit something else after a bullet
	 	end
	 end
	end
	pl.score += e.score >> 16

	del(actors, e)
	printh(e.k.." dead "..e.x)			 	
	
	if e.k == lander then
	 wave.landers_hit += 1
	 
	 if e.target ~= nil then
		 if e.target.capture == capture_lifted then
		 	-- todo drop human
		 	-- todo set drop time / score depending on height/landing
		 	printh("todo drop human!")
		 	e.target.dy = gravity_speed
		 	e.target.capture = nil
		 end
		end
	 
	 -- note: could have just added a batch! todo fifo?
	 if wave.landers_hit % 5 == 0 then
			if wave.landers > 0 then	 
			 printh("more at #"..wave.landers_hit)
				add_enemies()
			end
		end
	elseif e.k == mutant then
	 wave.landers_hit += 1  -- same as lander since we can compare with spawn number 1 for 1
		-- todo track separate hits too?
	elseif e.k == bomber then
	 wave.bombers_hit += 1
	 -- todo more?
	elseif e.k == pod then
	 wave.pods_hit += 1
	 -- todo more?
	elseif e.k == human then
		if e.capture ~= nil then
	  printh("dead human was captured "..e.x.." "..e.capture)
	  -- reset any lander that had this as a target (else picks up a phantom)
	 	for a in all(actors) do
	 		if a.k==lander and a.target==e then
	 			printh("unlinking target after human dead "..a.target.x.." "..a.x)
	 			a.target = nil
	 		end
	 	end
		end
	 humans -= 1
	 -- todo if humans == 0 then null space: convert all landers to mutants
	end
	if is_wave_complete() then
	 pl.hit = time()  -- pause
	 add_pl_score(humans * 100*min(iwave+1,5))
		_draw = _draw_end_wave
	end
end

function kill_player(e)
 pl.hit = time()
 -- todo remove: t_chunk is reset by reset_enemies() later
	wave.t_chunk -= player_die_expire  -- don't include dying time
 cdx = 0 -- freeze
 for i=1,16 do
  local d = sp[i]
	 pl.x+=d[1]*rnd(4)
	 pl.y+=d[2]*rnd(4)
	 add_explosion(pl, false, rnd(particle_speed)+0.1, player_die_expire)
	end 
	--note: pl x/y adjusted - don't bother to restore since we're dying
	--printh(#particles)
	pl.lives -= 1
	add_pl_score(25)
	
	printh("player killed by "..e.x)
	kill_actor(e, nil, false)  -- no explosion

	if pl.lives < 0 then
	 pl.hit = time()  -- pause
		_draw = _draw_game_over
		-- repoint update60 & draw!
	end

	--note reset_enemies() will be called during draw (i.e. after death animation)
end

function add_humans()
 -- todo pass in t?
	for h = 1,humans do
	 local x=rnd(ww)  -- todo groups?
	 local y=120 - flr(rnd(4))
		h=make_actor(human,x,y,time())
		h.c=6
		h.dx=rnd(human_speed)  
		if (rnd() > 0.5) h.dx=h.dx*-1
		h.h=6
		h.w=2
		h.capture=nil
	end
end


function is_wave_complete()
	local r = 0
 -- spawned
	for e in all(actors) do
  if (not(e.k == bullet or e.k == mine or e.k == human)) r+= 1
 end
	-- plus yet to spawn
	r += wave.landers
	r += wave.bombers
	r += wave.pods
	-- todo? baiters
	-- todo? swarmers	
	-- note: mutants don't spawn initially but they accrue during play
	r += wave.mutants  
	printh("r="..r)
	printh(wave.landers_hit)
	return r == 0  -- i.e. no more left
end

function load_wave()
	local t=time()
	local sw = waves[iwave%8+1]
	-- copy
	wave={
 	 c=sw.c,
 		landers=sw.landers,
 		bombers=sw.bombers,
 		pods=sw.pods,	
 		
 		mutants=0,
 		
 		t=t,
 		t_chunk=t,
 		
 		landers_hit=0,  -- include mutants
 		bombers_hit=0,
 		pods_hit=0,
 		-- todo baiters_hit
 		-- todo swarmers_hit
 		
 		humans_added=nil,
	}

	if iwave == 0 or ((iwave+1)%5 == 0) then
  -- replenish
		wave.humans_added = 10 - humans
		humans += wave.humans_added
		-- todo: use humans_added to avoid re-adding
		printh("adding humans "..wave.humans_added.."="..humans)
	end

	if	debug_test then
		wave.landers=2 --1
		wave.bombers=min(1,wave.bombers)
		wave.pods=min(1,wave.pods)
	end
end

function add_enemies()
 -- todo pass in t?
 -- see reset_enemies for undo
	if wave.landers > 0 then
	 make = min(wave.landers, 5)
		for e = 1,make do
		 local x=rnd(ww)
		 --local y=rnd(128-hudy)+hudy
		 local y=hudy+2
		 -- todo if hit player - move
			-- note: pass hit time = birthing - wait for implosion to finish  note: also avoids collision detection
			l=make_actor(lander,x,y,time())
			l.dy = lander_speed/2
			l.lazy = rnd(512)  -- higher = less likely to chase
			l.h=4
			l.w=3
			l.score=150	
			-- find target
			l.target = nil
			if true then --humans > 0 then
				for i,e in pairs(actors) do
					if e.k == human and e.capture==nil then
						l.target=e
						l.target.capture = capture_targetted
						printh(l.x.." targetting "..i.." = "..e.x)
						break
					end
				end
			end
			add_explosion(l, true)  -- reverse i.e. spawn
		end
		wave.landers -= make
	end
	if wave.mutants > 0 then
	 make = wave.mutants
		for e = 1,make do
		 local x=rnd(ww)
		 --local y=rnd(128-hudy)+hudy
		 local y=hudy+2
		 -- todo if hit player - move
			-- note: pass hit time = birthing - wait for implosion to finish  note: also avoids collision detection
			l=make_actor(mutant,x,y,time())
			l.dy = mutant_speed/2
			-- todo remove lazy here?
			l.lazy = rnd(512)  -- higher = less likely to chase
			l.h=4
			l.w=3
			l.score=150	
			add_explosion(l, true)  -- reverse i.e. spawn
		end
		wave.mutants -= make
	end
	if wave.bombers > 0 then
	 make = min(wave.bombers, 5) -- ok?
		for e = 1,make do
		 local x=rnd(ww)
		 --local y=rnd(128-hudy)+hudy
		 local y=hudy+2
		 -- todo if hit player - move
			-- note: pass hit time = birthing - wait for implosion to finish  note: also avoids collision detection
			l=make_actor(bomber,x,y,time())
			--l.dy = lander_speed/2
			l.lazy = rnd(512)  -- higher = less likely to chase
			l.h=4
			l.w=3
			l.score=250	
			add_explosion(l, true)  -- reverse i.e. spawn
		end
		wave.bombers -= make
	end
 if wave.pods > 0 then
	 make = min(wave.pods, 5) -- ok?
		for e = 1,make do
		 local x=rnd(ww)
		 --local y=rnd(128-hudy)+hudy
		 local y=hudy+2
		 -- todo if hit player - move
			-- note: pass hit time = birthing - wait for implosion to finish  note: also avoids collision detection
			l=make_actor(pod,x,y,time())
			--l.dy = lander_speed/2
			l.lazy = rnd(512)  -- higher = less likely to chase
			l.h=4
			l.w=3
			l.score=1000	
			add_explosion(l, true)  -- reverse i.e. spawn
		end
		wave.pods -= make
	-- todo others
	end
	-- based on wave.t? and/or remaining
end

function	reset_enemies()
	-- undo add_enemies/add_humans
	-- push active enemies back on wave and setup re-spawn
	t = time()
	for e in all(actors) do
		-- todo check not just hit?
		if e.k == bullet then
			printh(e.k.." removed "..e.x)			 	
		elseif e.k == lander then
			printh(e.k.." undead "..e.x)			 	
			wave.landers	+= 1
		elseif e.k == mutant then
			printh(e.k.." undead "..e.x)			 	
			--note: no need: already added on conversion: 
			wave.mutants	+= 1
		elseif e.k == bomber then
			printh(e.k.." undead "..e.x)			 	
			wave.bombers	+= 1
		elseif e.k == pod then
			printh(e.k.." undead "..e.x)			 	
			wave.pods	+= 1
		elseif e.k == human then
			printh(e.k.." removed "..e.x)			 		
		else
			assert(false, "unknown e.k:"..e.k)		
		end
		del(actors, e)  -- todo: assuming we don't retain the positions on respawn!
	end
	-- prime the respawning
	wave.t_chunk = t - wave_progression + wave_reset  -- reset
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000bb000000bb00000099900000000000000000000000000000000000000000000000000
00700700000000000660000000000000000000000000000000000000000fb000000fb00000b0b0b0000000000000000000000000000000000000000000000000
0007700000000000e66600000000000000070700000000000000000000022e0000022e0000b9b9b0000000000000000000000000000000000000000000000000
00077000000000006e66661000000000000077000000000000000000000e2e00000e2e00000bbb00000000000000000000000000000000000000000000000000
007007000d000000eee6666b00000000000707000d00000000000000000020000002000000b0b0b0000000000000000000000000000000000000000000000000
00000000dddd1900000000000000000000000000eed1000000000000000020000002000000000000000000000000000000000000000000000000000000000000
000000000e73dd730000000000000000000000000edd300000000000000000000000000000000000000000000000000000000000000000000000000000000000
50505005550500550055050505055055505550505055555057755555555555550000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550000000000020000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550000000000b2eb00000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550007700000b2eb00000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550007700000b20b00000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550000000000b00b00000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b7b88000097e8000b0970000897b800000000000000000000000000000000000000000bbbbbb0000000000000000000000000000000000000000000000000
0099078e007b789000787eee00b08778000000000000000000000000000000000000000000bbbb00000000000000000000000000000000000000000000000000
00007700000000e90000097000009900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000b00000000000000000000000000000000000000000000eee00000000000000000000000000000000000000000000000000
00000908000007e800000970000007780000000000000000000000000000000000000000000cce00000000000000000000000000000000000000000000000000
0000077e0000087000000eee000009000000000000000000000000000000000000000000000cce00000000000000000000000000000000000000000000000000
00000708000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000022200000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000221220000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000022200000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000088800000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000888880000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000b0b000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000b0000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000b0b000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000444444444444444444444444444777777777744444444444444444444444444440000000000000000000000000000000
04440444044400000440044404040444400000000000000000000000000700000000700000000000000000000000000040000000000000000000000000000000
04000404040400000040000404040004400000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000
04440444044400000040004404440444400000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000
00040004000400000040000400040400400000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000
04440004000400400444044400040444400000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000
000000000000000000000000000000004000000000000000000000000000b0000000000000400000000000000444000040000000000000000000000000000000
70000000000004440444044400000000400004000000000000000000004000048044004444044404000000004000000040000000000000000000000000000000
07000000000000040404000400000000400440444400000000000000040444404400440000000040400000040000000040000000000000000000000000000000
00700000000000040444000400000000444000000040400000000000400000000000000000000000040000400000000440000000000000000000000000000000
07000000000000040004000400000000400000000004040400040004000000000000000000000000004444000000444040000000000000000000000000000000
70000000000000040004000400000000400000000000004044404440000700000000700000000000000000000000000040000000000000000000000000000000
00000000000004444444444444444444444444444444444444444444444777777777744444444444444444444444444444444444444444444444444444444444
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b0b0b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b9b9b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0bbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004440000000000000000000
b0b0b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040004000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000400000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000040000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004040000000004000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040400000000000400000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000040000000000000
00000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000004000000000000000004000000000000
00000000000000000000000000000000000000000040400000000000000000000000000000000000000000000000000040000000000000000000400000000000
00000000000000000000000000000000000000000400040400000000000000000000000000000000000000000000000400000000000000000000040000000000
00000000000000000000000000000000000040004000004040004000000000000000000000000000000000000000004000000000000000000000004000000000
00000000000000000000000000000000000404040000000004040400000000000000000000000000000000000000040000000000000000000000000400000000
00000000000000000000000000000000004000400000000000400040000000000000000000000040000000000000400000000000000000000000000040400000
00000000000000000000000000000000040000000000000000000004000000000660000000000404000000000004000000000000000000000000000004040000
0000000000000000000000000000000040000000000000000000000040000000e666000000004000400000000040000000000000000000000000000000004000
00000000000000000000000004000004000000000000000000000000040000006e66661000040000040000000400000000000000000000000000000000000400
0000000000000000000000004040004000000000000000000000000000400000eee6666b00400000004000004000000000000000000000000000000000000040
00000000000000000000000400040400000000000000000000000000000400000000000004000000000400040000000000000000000000000000000000000004
00000000000000000040404000004000000000000000000000000000000040000000000040000000000040400000000000000000000000000000000000000000
00000000000000000404040000000000000000000000000000000000000004000000040400000000000004000000000000000000000000000000000000000000
00000000000000004000000000000000000000000000000000000000000000400000404000000000000000000000000000000000000000000000000000000000
00000000000000040000000000000000000000000000000000000000000000040004000000000000000000000000000000000000000000000000000000000000
40000000000000400000000000000000000000000000000000000000000000004040000000000000000000000000000000000000000000000000000000000000
04000000000004000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000
00400000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00004000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000400040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1011121314151513121716170000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0001000024050260502705029050000002c0502e05000000320500000034050350502f0502d05025050210501e050180501605015050150501605018050000001a0501a0501a0501905000000000000000000000
