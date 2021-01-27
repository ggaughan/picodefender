pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- pico defender
-- ggaughan, 2021
-- remake of the williams classic

debug = true

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

max_speed = 3
thrust = 1
vert_accel = 0.6
max_vert_speed = max_speed/2
max_h_speed_factor = max_speed/48

laser_expire = 1
laser_size = 40  -- see rate
laser_rate=8
laser_max_length = 50  -- cap
laser_min_length = 6  -- show something immediately
min_laser_speed = 0.1  -- e.g. static ship, move away still
laser_speed = 1.8
laser_inertia = 0.999

lander_speed = 0.3
bullet_expire = 1.5
bullet_speed = 1.6

particle_expire = 1
particle_speed = 0.8
--enemy_explode_size = 32

player_die_expire = 3
old_particle = 1
enemy_die_expire = 1

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
	
	waves = {
	 {--1
 	 c=1,
 		landers=15,
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
	iwave=0
	load_wave()
	-- todo wrap iwave display to 2 digits (100 and 200 show as 0 when completed) 
	--      then actually wrap at 255 with special wave 0
	add_enemies()
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
	 
	 cx += cdx * pl.facing
	 pl.x += cdx * pl.facing
	 cdx *= inertia_cx
	
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
	-- else player dying
	end
end

function update_enemies()
	local t = time()
	for e in all(actors) do
		-- check if hit by laser
	 for laser in all(lasers) do 	
	  if not e.hit then
				local actual_age = (t-laser[4]) --/ laser_expire
				if actual_age > 0.05 then
					local x,y = laser[1], laser[2]
				 -- todo precalc half widths			
				 -- todo include wrap at end
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
			if (abs(ceil(x)) < (e.w+pl.w) and
					 (abs(ceil(y))) < (e.h+pl.h))
			then
	 		e.hit = t
			 kill_player(e)
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
				
				if e.k == 9 then  --lander
					off = rnd(hudy*2)
					if e.y < hudy + off then
						e.y = hudy + off
						e.dy *= -1
					elseif e.y > 120 - off then
						e.y = 120 - off
						e.dy *= -1
					end 
					
					-- ai
					if abs(e.x - pl.x) < (rnd(256) - e.lazy) then
					 if e.x < pl.x then
						 e.dx = lander_speed
						else
						 e.dx = -lander_speed
					 end
					end
					if abs(e.x - pl.x) < 128 then
						if rnd() < 0.005 then
							b=add_bullet(e.x, e.y)
						end
					end
					if rnd() < 0.2 then
						e.dx = lander_speed/4
					elseif rnd() < 0.2 then
						e.dx = -lander_speed/4
					elseif rnd() < 0.2 then
						e.dx = 0
					end
				elseif e.k == 24 then
			 	if t-e.t > bullet_expire then
			 		del(actors,e)
			 	end
				-- else other types
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
  print((t%0x0.0005<<17)+(v<<16&1),i*4,6,8)
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
	 --if e.k~=24 then
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
	for laser in all(lasers) do
		--printh(tostr(laser))
		local x,y = wxtoc(laser[1]), laser[2]
		local age = (t-laser[4]) / laser_expire
		local mdx,mdy=1/8,0
		tline(x,
							y,
				  	x+min(
					  	max((age * laser_size) * laser_rate, 
    		  				laser_min_length
				  			  ) * laser[3]
		  				, 
				  		laser_max_length
				  		), 
				  	y, 
				  	0,0,
				  	mdx,mdy
		)
	end

	if pl.hit ~= nil then
		local age = (t-pl.hit)
		printh("player dying "..age)
		if age > player_die_expire then
			pl.hit = nil
			printh("player rebirth "..age)
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
				printh("enemy birthed "..age)
			else
				printh("enemy birthing "..age)	
			end
		else
			local x,y = wxtoc(e.x), e.y
			spr(e.k, x, y, 1,1)	
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

function _draw()
 cls()
 
 if canim > 0 then
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
	b=make_actor(24,x,y)
	-- todo aim at pl!
	b.dx = ((pl.x - b.x)/128) * bullet_speed
	b.dy = ((pl.y - b.y)/128) * bullet_speed
	b.t = t()
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
	explode = explode or true
 if explode then
		if e.k ~= 24 then
		 add_explosion(e)
	 	if laser then
	 		del(lasers,laser)  -- i.e. allow to hit something else after a bullet
	 	end
	 end
	end
	pl.score += e.score >> 16

	del(actors, e)
	printh(e.k.." dead "..e.x)			 	
	
	if e.k == 9 then
	 wave.landers_hit += 1
	 if wave.landers_hit % 5 == 0 then
			if wave.landers > 0 then	 
				add_enemies()
			end
		end
	end
	
	-- wave complete?
	-- todo sum wave.landers etc
end

function kill_player(e)
 pl.hit = time()
 cdx = 0 -- freeze
 for i=1,16 do
  local d = sp[i]
	 pl.x+=d[1]*rnd(4)
	 pl.y+=d[2]*rnd(4)
	 add_explosion(pl, false, rnd(particle_speed)+0.1, player_die_expire)
	end 
	--note: pl x/y adjusted - don't bother to restore since we're dying
	printh(#particles)
	pl.lives -= 1
	add_pl_score(25)
	printh("player killed by "..e.x)
	kill_actor(e, nil, false)  -- no explosion
	
	if pl.lives < 0 then
	 --assert(false)
		-- todo game over mode
		-- repoint update60 & draw?
	end
end

function load_wave()
	local sw = waves[iwave%8+1]
	-- copy
	wave={
 	 c=sw.c,
 		landers=sw.landers,
 		bombers=sw.bombers,
 		pods=sw.pods,	
 		
 		landers_hit=0,
 		bombers_hit=0,
 		pods_hit=0,
 		-- todo mutants=ex-landers
 		-- todo baiters
 		-- todo bombbers
 		-- todo swarmers	
	}
end

function add_enemies()
 -- todo pass in t?
	if wave.landers > 0 then
	 make = min(wave.landers, 5)
		for e = 1,make do
		 local x,y=rnd(ww),rnd(128-hudy)+hudy
		 -- todo if hit player - move
			-- note: pass hit time = birthing - wait for implosion to finish  note: also avoids collision detection
			l=make_actor(9,x,y,time())
			l.dy = lander_speed
			l.lazy = rnd(512)  -- higher = less likely to chase
			l.h=4
			l.w=3
			l.score=150	
			add_explosion(l, true)  -- reverse i.e. spawn
		end
		wave.landers -= make
	end
	-- todo others
end


__gfx__
00000000000000000000000000000000000000000000000000000000000000000009900000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000b99b0000099900000000000000000000000000000000000000000000000000
00700700000000000660000000000000000000000000000000000000000000000bb0b0b000b0b0b0000000000000000000000000000000000000000000000000
0007700000000000e666000000000000000707000000000000000000000000000bb0b0b000b9b9b0000000000000000000000000000000000000000000000000
00077000000000006e666610000000000000770000000000000000000000000000b9b900000bbb00000000000000000000000000000000000000000000000000
007007000d000000eee6666b00000000000707000d000000000000000000000000b0bb0000b0b0b0000000000000000000000000000000000000000000000000
00000000dddd1900000000000000000000000000eed1000000000000000000000b00b0b000000000000000000000000000000000000000000000000000000000
000000000e73dd730000000000000000000000000edd30000000000000000000b000b00b00000000000000000000000000000000000000000000000000000000
70707007770700770077070707077077707770707077777077777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777770007700000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777770007700000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b7b88000097e8000b0970000897b8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0099078e007b789000787eee00b08778000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007700000000e90000097000009900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000908000007e80000097000000778000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000077e0000087000000eee00000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000708000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0000000000000000020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1011121314151617000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0001000024050260502705029050000002c0502e05000000320500000034050350502f0502d05025050210501e050180501605015050150501605018050000001a0501a0501a0501905000000000000000000000
