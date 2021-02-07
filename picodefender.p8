pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- pico defender
-- ggaughan, 2021
-- remake of the williams classic

debug=true
debug_test=not debug  
debug_kill=not debug

epi_friendly=false

today,alltime=1,2
e_hs={nil,0}
highscores = {
	{e_hs,e_hs,e_hs,e_hs,e_hs,e_hs,e_hs,e_hs},
	{e_hs,e_hs,e_hs,e_hs,e_hs,e_hs,e_hs,e_hs},
}

ww = 128 * 9  --1152
cx = 128 * 4
ocx = cx

hc = 128/4
hudy,hudw=12,hc*2
hwr = ww/hudw
hhr = (128-4 - hudy)/hudy + 1
lmax = 82

human=7
lander=9
mutant=25
bomber=57
pod=73
swarmer=89  -- from pod
baiter=41  -- spawn near end of level
mine=105  -- from bomber
bullet=24	

demo_sx=108
demo_sy=(128-hudy)/2
demo_ty=14
demo={
	t=0,  -- 0 = not started
	step=0,
	step_next_part=1,
	steps={
		{lander},
		{mutant},
		{baiter},
		{bomber},
		{pod},
		{swarmer}
	}
}
-- note: ns match steps
ns="lander,mutant,baiter,bomber,pod,swarmer"
names=split(ns)
attrs={
	[lander]={100,11,5,7,3},
	[mutant]={150,11,5,7,3},
	[baiter]={200,11,4,7,3},
	[bomber]={250,14,4,4,3},
	[pod]={1000,8,5,7,4},
	[swarmer]={150,9,4,5,1},
	
	[human]={500,6,6,3,2},
	
	[bullet]={0,6,1,1,1},
}


max_stars=100

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

inertia_py = 0.95
inertia_cx = 0.98

max_speed = 2
thrust = 0.4
vert_accel = 0.6
max_vert_speed = max_speed/2
max_h_speed_factor = max_speed/48

laser_expire = 0.5
laser_size = 22  -- see rate
laser_rate=4
laser_max_length = 100  -- cap
laser_min_length = 8  -- show something immediately
min_laser_speed = 0.2 -- e.g. static ship, move away still
laser_speed = 2.0
laser_min_effective_age = 0.03  -- delay so it can be seen before being effective
laser_inertia = 0.999

lander_speed = 0.15
lander_speed_y_factor = 2
mutant_speed = 0.3
baiter_speed = 2.2  -- faster than player  -- todo set to max_speed*factor?
bomber_speed = 0.3
pod_speed = 0.2
swarmer_speed = 0.7
swarmer_inertia = 1 --0.99
bullet_expire = 1.4  -- todo depend on actual bullet_speed?
bullet_speed = 0.02
mine_expire = 6

particle_expire = 0.8
particle_speed = 0.6
--enemy_explode_size = 32

player_birth_expire = 1
player_die_expire = 3
old_particle = 1
enemy_die_expire = 1

max_humans = 10
human_speed = 0.02
target_x_epsilon = 3
target_y_epsilon = 4
capture_targetted = 1
capture_lifted = 2
gravity_speed = 0.1
safe_height = 80

wave_progression = 15  -- seconds
wave_old = 60  -- min before baiters
baiter_next = wave_progression / 3  -- delay baiter re-spawn based on last 3 enemies
max_baiters = 4
max_swarmers = 20
wave_reset = 2  -- seconds
delay_first_enemies = 0.5 -- give time for initial music to finish

extra_score_expire = 1
bombing_expire = 0.3
ground_destroy_expire = 2

title_delay = 8
title_particle_expire = 1.4
game_over_delay = 4
new_highscore_delay = 60  -- timeout if no initials in this time
hs_chr = "a"

--if debug_test then
--	max_humans = 1
--end

function _init()
	cart_exists = cartdata("ggaughan_picodefender_1")

	-- todo save on cart?
	menuitem(1, "toggle flashing", function() epi_friendly,cc=not epi_friendly,10 end)

	w = {}  -- ground level
	sw = {} -- scanner ground summary
	stars = {}
	cx = 128 * 4
 cdx = 0
 canim,canim_dx=0,0

	build_world()  -- if this takes any time, move to update60_title, i.e. draw something first
	add_stars()
	
	load_highscores()
	
	pl = {
		w=6,
		h=3,

	 c=7,  -- for explosion
	 
	 thrusting_t=0,
	 thrusting_spr=0,
	 hit=nil,  -- also used for timeouts/delays	
	}

	actors = {}
	particles = {}
	
	reset_player(true)  -- todo remove? will be called via start_game()
	-- todo move to reset_game(true) - include call to reset_player(true) above
	lasers = {}
	iwave=0
	humans=0  -- topped up by load_wave
	add_humans_needed = true
	-- todo remove: start_game does this: can't do more than once:
 load_wave() -- added back for demo
	-- todo wrap iwave display to 2 digits (100 and 200 show as 0 when completed) 
	--      then actually wrap at 255 with special wave 0
	
	-- palette rotate	
	pt = time()
	cc = 1
	
	extra_score = nil
	bombing_t = nil  -- also used for title animation and null space ground explode
	bombing_e = bombing_expire  -- todo rename bombing_e -> flash_e
	
	-- todo pl.hit still needed here?
 pl.hit = time()  -- delay
	_draw = _draw_title
	_update60 = _update60_title
end



-->8
--update

function _update60_wave()
 local t=time()

 update_particles()  -- could include player dying

	if pl.hit==nil and pl.birth==nil then
	 if btnp(⬅️) then
	  -- todo avoid repeat with re-press
		 pl.facing*=-1
		 -- start reverse animation
		 canim=80
		 canim_dx=pl.facing
	  cdx*=0.5
		end
	 if (btn(➡️)) cdx=min(cdx+thrust,max_speed)
	 if btn(⬆️) then
	  pl.dy-=vert_accel
	  if (pl.dy<-max_vert_speed) pl.dy=-max_vert_speed
	 end
	 if btn(⬇️) then
	  pl.dy+=vert_accel
	  if (pl.dy>max_vert_speed) pl.dy=max_vert_speed
	 end
	
	 if btnp(❎) then
			-- fire laser - todo limit 
	  local x=pl.x
	 	if (pl.facing>0)	x+=11
	 	add(lasers, {x-2,pl.y+5,pl.facing,t,max(cdx, min_laser_speed)})
	 	sfx(0)
	 end
	 -- update any existing lasers
	 for laser in all(lasers) do
	 	laser[1]=(laser[1] + laser[5]*laser[3] * laser_speed)%ww
	 	laser[5]*=laser_inertia
	 	if (t-laser[4]>laser_expire) del(lasers,laser)
	 end
	 
	 if btnp(🅾️) then 
	 	if btn(⬆️) and btn(⬇️) then
	 		-- hyperspace
	 		pl.birth=t
	 		local hx=rnd(ww)
	 		cx+=hx
	 		pl.x+=hx
	 		if (rnd()<0.5) pl.facing*=-1
	 		cdx=0
			 canim,canim_dx=80,pl.facing
				add_explosion(pl, true)
	 		-- todo sfx 
	 	else 
		 	-- smart bomb - kill all enemies
		 	if pl.bombs>0 then
			 	sfx(6)
			 	bombing_t,bombing_c=t,7
			 	bombing_e=bombing_expire
					for e in all(actors) do
					 -- note: we kill bullets and mines too
					 -- note: original doesn't seem to...
				  if not(e.k==human) then
							local sx=wxtoc(e.x)
							if sx>=0 and sx<=127 then
								e.hit=t
							 kill_actor(e, nil)
							end
				  end
					end	
		 		pl.bombs-=1
			 end
			end
	 end
	 
	 pl.dy*=inertia_py
	 pl.y+=pl.dy 
	 
	 cdx*=inertia_cx
	 cx=(cx+cdx*pl.facing)%ww
	 pl.x+=cdx*pl.facing  -- note: effectively pl.dx
	
		-- player thrust/decay
		-- in screen space to handle any wrapping
		local x=wxtoc(pl.x)
	 if pl.facing==1 then
	 	if (x<40 and btn(➡️)) pl.x+=cdx * max_h_speed_factor
	 	if (x>20 and not btn(➡️)) pl.x-=thrust/2  -- fall back
	 else
	 	if (x>80 and btn(➡️)) pl.x-=cdx * max_h_speed_factor
	 	if (x<100 and not btn(➡️)) pl.x+=thrust/2  -- fall back
	 	-- assumes <128, if not we're off camera but will move
	 end
	 
		if btn(➡️) then
			pl.thrusting=true
		 sfx(3)
		else 
	 	pl.thrusting=false
			sfx(3, -2)
		end
	 if t-pl.thrusting_t>0.05 then
			pl.thrusting_spr=(pl.thrusting_spr+1)%4
			pl.thrusting_t=t
		end

	 -- player wrap
	 pl.x=pl.x%ww
	 -- todo retain screen offset pos!
	 
	 if pl.y<hudy then
	 	pl.y, pl.dy=hudy,0
	 elseif pl.y>120 then
	  pl.y,pl.dy=120,0
	 end

	 update_enemies()  -- checks for player hit  

	 -- todo could do every other frame? move to update_enemies/humans?
	 for plt in all(pl.target) do
		 if plt.capture==capture_lifted then
		 	plt.x=pl.x 
		 	plt.y=pl.y+6 
		 	-- todo dx/dy?

				if plt.y>116 then
			 	--printh("dropping "..plt.x)
 		 	plt.x+=rnd(8)-4
 		 	plt.y+=rnd(8)-4
			 	plt.dy=gravity_speed
			 	plt.dropped_y=pl.y
			 	-- todo set walking again?
					-- todo sfx?
		 		-- note: x-12 since score formats for 6 places
					add_pl_score(plt.score, plt.x-12, plt.y+4)	-- note: only 1 displayed (timer)
					plt.capture=nil
			 	del(pl.target,plt)
			 end
			end
	 end
	 
	 update_wave()
 
	else
	 -- player dying or being born
	 -- or pausing between waves
	 -- either way, fixed via draw_player timeout
	end
end

function update_enemies()
	local t = time()
	for e in all(actors) do
 	if e.k ~= mine then
			-- check if hit by laser
		 for laser in all(lasers) do 	
		  -- maybe ignore overlaps? index lasers by y?
		  if not e.hit then
		   -- note: if multiple hit: 1st in actors is hit: todo sort?
		   -- test y first = faster? less filtery though?
					local age=(t-laser[4])/laser_expire
					-- todo add min age check so we know we've been drawn
					local x,y = laser[1], laser[2]			
					local tl=age * laser_size * laser_rate
					local tx=x+(laser[3]*tl) -- no wrap, could be -ve
					-- no wrap e.x, to match tx (side handles wrap)
					if (laser[3]>0 and side(x,e.x,laser[3]) and tx > (e.x+e.xl+e.dx) 
					   or 
					   laser[3]<0 and side(x,e.x,laser[3]) and tx < (e.x+e.xr+e.dx)) then
						if y >= e.y+e.dy+e.yt and y <= e.y+e.dy+e.yb then
							--printh("laser hit "..e.x.." from "..x.." "..tx)
				 		e.hit = t
						 kill_actor(e, laser)
						end
					end
			 end		
			end
		end
		
		if not e.hit then  
			-- check if hit player
		 -- todo include wrap at end
		 -- note: assumes all are drawn centred
			local x=(e.x+4+e.dx) - (pl.x+4)
			local y=(e.y+4+e.dy) - (pl.y+4)  
			if e.k ~= human then
				if abs(x)*2 < (e.w+pl.w) and
						 abs(y)*2 < (e.h+pl.h)
				then
--					if debug_kill then
--						pl.dy = 0
--					 debug_data = {(e.x+e.xr+e.dx),
--					 														(e.y+e.yb+e.dy), 
--					 														(pl.x+(8-pl.w)/2)+pl.w/2, 
--					 														(pl.y+(8-pl.h)/2)+pl.h/2,
--					 												  (e.w+pl.w),(e.h+pl.h)}
--					 printh(x.."<"..(e.w+pl.w))
--					 printh(y.."<"..(e.h+pl.h))
--					 printh(debug_data[1].." "..debug_data[3])
--					 printh(debug_data[2].." "..debug_data[4])
--					 _update60=_update60_debug_stop
--					else
					if not debug_kill then
		 			e.hit = t
				 	kill_player(e)
				 end
				end
			else -- human - can we catch it?
				-- note: no need to wrap assumes will line up on x at some point - if not we could wrap in wxtoc
				if e.capture == nil and e.y<116 and abs(e.x-pl.x)<target_x_epsilon*2 and abs((e.y-4)-pl.y)<target_y_epsilon*2 then
			 	--printh("catching! "..e.x.." "..pl.x..":"..e.y.." "..pl.y)
					e.capture = capture_lifted
			 	add(pl.target,e)
			 	e.dy = 0 --pl.dy
			 	e.dx = 0 --pl.dx = cdx * pl.facing
					-- todo sfx?
					-- note: x-12 since score formats for 6 places
					add_pl_score(e.score, pl.x-12, pl.y+4)
				end
			end			
			
			if not e.hit then
				e.x = (e.x + e.dx) % ww
		  e.y += e.dy
			
				if demo.t == 0 then	
					-- todo move to ai/behaviour routine
					if e.k == lander then  
						if e.target ~= nil then
							-- todo wrap
						 if e.target.capture == capture_lifted then
						 	--printh("lifting "..e.x.." "..e.target.x)
						 	e.target.x = e.x 
						 	e.target.y = e.y + 7
						 	-- todo dx/dy?
						 	if e.y <= hudy then
						 		--printh("convert to mutant"..e.x)
						 		kill_actor(e.target,nil,false)  -- kill human silently
						 		-- possibly now nullspace
						 		--no need: already decremented and reset_enemies will notice: wave.landers -= 1  -- spawn 1 less
						 		e.k = mutant
						 		--note: reset_enemies will do this: wave.mutants += 1  -- note: reset_enemies won't do this
						 		e.lazy = 0  -- todo or remove altogether?
									l.dy = mutant_speed*lander_speed_y_factor
						 	end
						 elseif e.target.capture == capture_targetted and abs(e.x - e.target.x) < target_x_epsilon and abs(e.y - e.target.y) < target_y_epsilon then
						 	--printh("capturing! "..e.x.." "..e.target.x)
						 	e.dy = -lander_speed*(lander_speed_y_factor/2)
						 	e.dx = 0  -- straight up
								e.target.capture = capture_lifted
								e.target.dy = gravity_speed  -- for if/when dropped
								e.target.dx = 0 -- stop any walking
								sfx(10)
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
						
						enemy_attack(e)
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
	
						enemy_attack(e)
					elseif e.k == baiter then
						-- ai
						-- todo less overlap with other baiters
						-- todo wrap/bug?
						local dx = abs(e.x - pl.x)
						if dx > 32+rnd(16) then
							-- todo need lazy here? yes to vary baiters
							if dx < (rnd(256) - e.lazy) then
							 if e.x < pl.x then
								 e.dx = baiter_speed
								else
								 e.dx = -baiter_speed
							 end
							end
						else 
	 					-- don't get too close
	 				 e.dx *= 0.96+rnd(0.08)  -- todo var inertia
	 				 if rnd() < 0.99 then
		 				 -- todo wrap/bug
		 				 if (e.x < pl.x) e.dx = -1  -- rand away
		 				 if (e.x > pl.x) e.dx = 1  -- rand away
		 				end
	 				 if rnd() < 0.02 then
	 				  e.dx *= -1  -- random move
	 				 end
						end	 
						local dy = abs(e.y - pl.y) 
						if dy > 16+rnd(16) then
						 if e.y < hudy + rnd(30) or (e.y < pl.y and e.dy<=0) then
						 	e.dy = baiter_speed/3
						 elseif e.y > 120 - rnd(30) or (e.y > pl.y and e.dy>=0) then
						 	e.dy *= -baiter_speed/3
						 end
						else
							-- don't get too close/ram
							e.dy = 0
	 				 if rnd() < 0.1 then
		 				 if (e.y < pl.y) e.dy = -1  -- rand away
		 				 if (e.y > pl.y) e.dy = 1  -- rand away
		 				end
	 				 if rnd() < 0.02 then
	 				  e.dx *= -1  -- random move
	 				 end
						end
	
					 enemy_attack(e)
					elseif e.k == bomber then
					 if e.y < hudy + rnd(30) or e.y > 120 - rnd(30) then
					 	e.dy *= -1
					 end
					 enemy_attack(e)
					elseif e.k == swarmer then
						-- ai
						-- todo overshoot
						if abs(e.x - pl.x) < (rnd(256) - e.lazy) then
						 if e.dx == 0 then
							 if e.x < pl.x or rnd()<0.05 then
								 e.dx = swarmer_speed
								else
								 e.dx = -swarmer_speed
							 end
							-- else already chasing - don't turn -- todo do eventually!
							end
	
							-- todo undulate: delay between y flips?					 
							--      or sin(e.t)?
						 if e.y < hudy + rnd(40) and e.y < pl.y and e.dy<0 then
						 	e.dy *= -1
						 elseif e.y > 120 - rnd(40) and e.y > pl.y and e.dy>0 then
						 	e.dy *= -1
						 end
						end
						-- overshoot?/don't get too close
					 e.dx *= swarmer_inertia --+rnd(0.08)  -- todo remove?
					 -- todo maybe if e.dx < limit set e.dx=0 and can chase again

 					enemy_attack(e)	
					elseif e.k == mine then
				 	if t-e.t > mine_expire then
				 		del(actors,e)
				 	end
					elseif e.k == bullet then
				 	if t-e.t > bullet_expire then
				 		del(actors,e)
				 	end
				 elseif e.k == human then
						if e.dropped_y ~= nil then
							-- gravity
						 if e.y > 119 then
						  -- don't bounce 
								e.y = 120 
								e.dy = 0 
								if e.dropped_y < safe_height then  -- i.e. unsafe
						 		kill_actor(e,nil,true)  -- kill human 
						 		-- possibly now nullspace						
								else
									add_pl_score(250)
								end
								e.dropped_y = nil
							end
						end 	 
					-- else other types
					end
					
					-- todo perhaps move enemy_attack() here and inside return if bullety or human?
				
					-- general bounce to stop y out of bounds
					if e.y<=hudy then
						e.y=hudy+1
						e.dy*=-1
					 if (e.k==bullet) del(actors,e)
					elseif e.y>120 then
						e.y=120 
						e.dy*=-1
					 if (e.k==bullet) del(actors,e)
					end 			
				else
					-- demo mode
					if e.y<hudy+demo_ty then
 					e.y=hudy+demo_ty -- once
						e.dy=0  -- stop and wait
						demo.step_next_part+=1
					end			
					if e.k==lander then  
						if e.target~=nil then
							-- todo wrap/re-use from above
						 if e.target.capture==capture_lifted then
						 	--printh("lifting "..e.x.." "..e.target.x)
						 	e.target.x=e.x 
						 	e.target.y=e.y + 7
						 	-- todo dx/dy?
	--						 	if e.y <= hudy then
	--						 		--printh("convert to mutant"..e.x)
	--						 		kill_actor(e.target,nil,false)  -- kill human silently
	--						 		-- possibly now nullspace
	--						 		--no need: already decremented and reset_enemies will notice: wave.landers -= 1  -- spawn 1 less
	--						 		e.k = mutant
	--						 		--note: reset_enemies will do this: wave.mutants += 1  -- note: reset_enemies won't do this
	--						 		e.lazy = 0  -- todo or remove altogether?
	--									l.dy = mutant_speed*lander_speed_y_factor
	--						 	end
						 elseif e.target.capture==capture_targetted and abs(e.x-e.target.x)<target_x_epsilon and abs(e.y-e.target.y)<target_y_epsilon then
						 	--printh("capturing! "..e.x.." "..e.target.x)
						 	e.dy=-lander_speed*3.1
						 	--e.dx = 0  -- straight up
								e.target.capture=capture_lifted
								e.target.dy=gravity_speed*3  -- for if/when dropped
								--e.target.dx = 0 -- stop any walking
								--todo demo.step_next_part+=1
							end
						-- else step 1 lander, not 0
						end
					end
				end			
			-- else hit and no more
			end
		-- else hit and no more
		end
	end
end

function update_particles()
	local t=time()
	for e in all(particles) do
 	if t-e.t > e.expire then
 		del(particles,e)
 	else
	  e.y+=e.dy  
	  if e.y<=hudy or e.y>127 then
	 		del(particles,e)
	  else
		  e.x=(e.x+e.dx)%ww
			 -- todo opt: cull if off-screen - though short-lived
			end
	 end
	end
end

-- todo rename: wave_progression
function update_wave()
	-- called regularly to top-up things
	-- note: wave_progression hacked to call on wave re-start e.g. after player death
	local t=time()
	local age = t-wave.t_chunk  -- since last update
	if age > wave_progression then
  wave.t_chunk = t  -- reset
		age = t-wave.t  -- total age
		if	add_humans_needed then
		 -- first call, add humans
			-- note: do even if humans==0 to reset the flag: if humans > 0 then
		 --printh("add_humans call at "..t)
			add_humans()
		end

		if wave.landers > 0 or wave.mutants > 0 or age > wave_old then	 
		 --printh("add_enemies call at "..t)
			add_enemies()
		end
	end
end

function _update60_game_over()
	local t=time()
	local age=t-pl.hit
	local timeout=age > game_over_delay
	local some_timeout=age > 1  -- make sure we see the message

 update_particles()  -- could include player dying
 
 if some_timeout and pl.score > highscores[today][8][2] then
		actors = {}  -- ok?
		particles = {}
		lasers = {}
		-- todo stop sfx

 	-- we have a highscore (at least for today)
 	hs_name = ""
 	hs_chr = "a"
  pl.hit = t
 	_update60 = _update60_new_highscore
 	_draw = _draw_new_highscore
 end
 
 if timeout or (some_timeout and btnp(➡️)) then
		actors = {}  -- ok?
		particles = {}
		lasers = {}
		-- todo stop sfx

  pl.hit = t
 	_update60 = _update60_highscores
 	_draw = _draw_highscores
 elseif some_timeout and (btnp(🅾️) or btnp(❎)) then
  start_game(true)
  
  pl.hit = t
 	_update60 = _update60_wave
 	_draw = _draw_wave
 end
end

function _update60_title()
	local t=time()
	--local age = t-pl.hit
	local timeout=(t-pl.hit) > title_delay
	
	if bombing_t==nil then
		add_explosion({x=cx+60,y=40, c=8}, true, particle_speed/2, title_particle_expire)
		--add_explosion({x=cx+64,y=50,c=8}, false, particle_speed, title_particle_expire)
		bombing_t = t
		bombing_e = bombing_expire -- todo increase here!
	end

 update_particles()  -- could include special effects
 
 if timeout or btnp(➡️) then
	 pal(10, 10)  -- after alt_cycle
  bombing_t = t  -- title explosion done
  particles={}
  pl.hit = t  
 	_update60 = _update60_highscores
 	_draw = _draw_highscores
	elseif btnp(🅾️) or btnp(❎) then
	 pal(10, 10)  -- after alt_cycle
  start_game(true)
  pl.hit = nil  -- start now
 	_update60 = _update60_wave
 	_draw = _draw_wave
 end
end

function _update60_highscores()
	local t=time()
	--local age=t-pl.hit
	local timeout=(t-pl.hit) > title_delay

 update_particles()  -- could include special effects
 
 if timeout or btnp(➡️) then
  pl.hit=t

		-- setup instructions - todo move to routine  
		demo.step=0
		demo.step_next_part=1
		demo.t=t -- start demo mode
		cx=ocx
		if true then -- when phase 2 ready
			-- todo move some to demo
			-- todo add add_human routine - though this isn't same/random
			h=make_actor(human,cx+demo_sx,116,time())
			h.capture=nil
			h.dropped_y=nil
			h.capture=capture_targetted
			--note: avoid (already setup) humans += 1
		end

		pl.facing=1
		-- todo pl.dy?		
		pl.lives=0
		pl.bombs=0
		pl.x=cx+8
		pl.y=hudy+12
		--- end setup

 	_update60=_update60_instructions
 	_draw=_draw_instructions
	elseif btnp(🅾️) or btnp(❎) then
  start_game(true)
  pl.hit=nil  -- start now
 	_update60=_update60_wave
 	_draw=_draw_wave
 end
end

function _update60_new_highscore()
	local t=time()
	--local age=t-pl.hit
	local timeout=(t-pl.hit) > new_highscore_delay

 update_particles()  -- could include special effects

	-- todo if key: pl.hit = t  -- reset timeout
	if btnp(⬆️) then  -- todo or ⬅️?
		-- todo wrap/limit
		hs_chr=chr(ord(hs_chr)-1)
		pl.hit=t  -- reset timeout
	elseif btnp(⬇️) then  -- todo or ➡️?
		-- todo wrap/limit
		hs_chr=chr(ord(hs_chr)+1)
		pl.hit=t  -- reset timeout
	elseif btnp(❎) then
		hs_name=hs_name .. hs_chr
		pl.hit=t  -- reset timeout
		if #hs_name>=3 then
			add_highscore(pl.score, hs_name)
	  pl.hit=t 
	 	_update60=_update60_highscores
	 	_draw=_draw_highscores
		end
	elseif btnp(🅾️) then
		if #hs_name>0 then
			hs_chr=sub(hs_name, #hs_name, #hs_name)
		 hs_name=sub(hs_name, 1, #hs_name-1)
		end
		pl.hit=t  -- reset timeout
 end

 if timeout then
  -- note: too late!
  -- 					 we still add with name of hs_name as-is (default "")
		add_highscore(pl.score, hs_name)
  pl.hit=t
 	_update60=_update60_highscores
 	_draw=_draw_highscores
 end
end

function _update60_instructions()
 -- note: uses actors and player logic to demo things
	local t=time()
	--local age=t-pl.hit
	local timeout=t-pl.hit>title_delay

	if demo then
	 -- note: we animate the enemies here unlike the original - todo:stop?
		local l
		-- todo first step = lander:human pickup/shoot/catch/drop
	 if demo.step<=#demo.steps then
	  timeout=false  -- hold
	  if demo.step==0 then
				if demo.step_next_part==1 then
					l=make_actor(lander,cx+demo_sx,hudy+demo_ty+16,t)
					l.target=h
					l.dy=lander_speed*4
					add_explosion(l,true)  
					demo.step_next_part+=1
				-- note: 2 = waiting to hit bottom/capture hit top
				elseif demo.step_next_part==3 then
			 	add(lasers, {pl.x+9,pl.y+5,pl.facing,time(),max(cdx, min_laser_speed)})
					demo.step_next_part+=1
				-- note: 4 = waiting to kill_actor
				elseif demo.step_next_part==5 then
				 -- wait for death explosion
			 	h.capture=nil
					if (t-bombing_t>particle_expire) demo.step_next_part+=1
				elseif demo.step_next_part==6 then
				 -- wait for drop 
					if (t-bombing_t>particle_expire) demo.step_next_part+=1
				elseif demo.step_next_part==7 then
					pl.x+=1.2
					pl.y+=0.5				
					if (pl.x>=cx+demo_sx) demo.step_next_part+=1
				elseif demo.step_next_part==8 then
					pl.y+=0.5				
			 	h.y=pl.y+6 
					if h.y>116 then
				 	h.dropped_y=pl.y
						add_pl_score(h.score, h.x-12, h.y+4)	
						demo.step_next_part+=1
					end
				elseif demo.step_next_part==9 then
					pl.facing=-1
					pl.x-=0.95
					pl.y-=0.81
					if pl.y<hudy+13 then
						pl.facing=1
						demo.step_next_part+=1
					end
				end
				if demo.step_next_part==10 then
					demo.step+=1 -- i.e. 1
					demo.step_next_part=1
				end 	
	  else
				if demo.step_next_part==1 then
					l=make_actor(demo.steps[demo.step][1],cx+demo_sx,demo_sy,t)
					l.dy=-lander_speed*3
					add_explosion(l,true)  -- reverse i.e. spawn
					demo.step_next_part+=1
				-- note: 2 = waiting to hit top
				elseif demo.step_next_part==3 then
					-- actor hit the top, shoot to kill
			 	add(lasers, {pl.x+9,pl.y+5,pl.facing,time(),max(cdx, min_laser_speed)})			
					demo.step_next_part+=1
				-- note: 4 = waiting to kill_actor
				elseif demo.step_next_part==5 then
				 -- wait for death explosion
					if (t-bombing_t>particle_expire) demo.step_next_part+=1
				elseif demo.step_next_part==6 then
					l=make_actor(demo.steps[demo.step][1],cx+12+((demo.step-1)%3*36),demo_sy-20+((demo.step-1)\3)*30,t)
					l.name=names[demo.step]
					-- note: draw name+score in draw
					add_explosion(l, true)  -- reverse i.e. spawn
					bombing_t=t
					demo.step_next_part+=1
				elseif demo.step_next_part==7 then
				 -- wait for reverse explosion
					if (t-bombing_t>particle_expire*1.2) demo.step_next_part+=1
				end
				if demo.step_next_part>7 then
					demo.step+=1
					demo.step_next_part=1
				end
			end
		else -- done them all - timeout should kick in
		 if demo.step==#demo.steps+1 then
				pl.hit=t  -- reset timeout
				demo.step+=1
				timeout=false
			end
		end
	end	

 update_particles()  -- could include special effects
 update_enemies()  -- checks for player hit

 if timeout or btnp(➡️) then
  actors={}
  demo.t=0 -- stop demo
  pl.hit=t  
  bombing_t=nil  -- title explosion reset
 	_update60=_update60_title
 	_draw=_draw_title
	elseif btnp(🅾️) or btnp(❎) then
  actors={}
  demo.t=0 -- stop demo
  start_game(true)
  pl.hit=nil  -- start now
 	_update60=_update60_wave
 	_draw=_draw_wave
 end
end

-- todo remove: debug only
function _update60_debug_stop()
 --update_particles()  -- could include special effects
end

-- todo move to tab3?
function start_game(full)
 if full then -- todo remove this check!
 	music(16,0,8)  -- review last 8 = channel 3 reserve
		reset_player(true)
		-- todo stop any sfx - e.g. player dying - or set min key delay > that sfx
		actors={}  -- ok?
		lasers={}
		iwave=0  -- todo leave out?
		if	debug_test then
			--iwave=1
		end
		humans=0  -- topped up by load_wave
		add_humans_needed=true
		load_wave()
	end

 bombing_t=nil
 bombing_e=bombing_expire
 particles={}
 add_humans()  -- initial 
 add_enemies(time()+delay_first_enemies) -- initial 
end

-->8
--draw

function wtos(wx,wy)
	local x=hc+((ocx+wx-cx)\hwr)%hudw
	local y=wy\hhr
	return x,y
end

function wxtoc(wx)
 -- note: we wrap here 
	local x=wx-cx
	if cx+128>ww then
		if (wx<(128-(ww-cx))) x=(wx+ww)-cx
	end
	return x
end

function side(l,e,cmp)
 -- cmp +1: is l to left of e?
 -- cmp -1: is e to left of l?
 if (e<128 and l>ww-128 and cmp==1) return true
 if (l<128 and e>ww-128 and cmp==-1) return true
	if (e>=l and cmp==1) return true
	if (e<=l and cmp==-1) return true
	return false
end

function draw_ground(force_ground)
	if force_ground or humans>0 then
		for x=0,127 do
			local i=((ceil(cx+x))%ww)+1
			pset(x,w[i], 4)
		end
	-- else null space
	end
end

function draw_score(v, x,y, extra)
	-- if extra, 1st of 3 digits will be yellow
 x=x or 0
 y=y or 6
 local c,i=5,6
 repeat
  local t=v>>>1
  if (extra and i==4) c=10 -- extra_score leading digit
  print((t%0x0.0005<<17)+(v<<16&1),x+i*4,y,c)
  v=t/5
 	i-=1
 until v==0
end

function add_pl_score(v, x, y)
 --assert(v<32767)  
 if (x and y) extra_score={v>>16, wxtoc(x),y, time()}
	pl.score+=v>>16
	pl.score_10k+=v>>16
	if pl.score_10k>=10000>>16 then
		pl.lives+=1
		pl.bombs+=1
		pl.score_10k-=10000>>16
		-- todo sfx
	end
end

function draw_hud(force_ground)
 local hdc=hudw/9
 
 -- ground
	if force_ground or humans>0 then
		for x=0,hudw-1 do
			local i=(x+(ocx+128+cx)\hwr)%hudw+1
			pset(hc+x,sw[i],4)
		end
	-- else null space
	end
	
	-- player
 local	sx,sy=wtos(pl.x,pl.y)
	pset(sx,sy,7)

	-- enemies
	for e in all(actors) do
	 -- todo skip if bullet? though handy!
	 --if e.k~=bullet then
		sx,sy=wtos(e.x,e.y)
		pset(sx,sy,e.c)
		--end
	end

	-- scanner box 
	local c=1
	if (wave) c=wave.c
	local sl,sr=hc+hdc*4-1,hc+hdc*5+1
	rect(hc,0,hc+hudw,hudy, c)
	line(0,hudy,127,hudy, c)
	line(sl,0,sr,0, 7)
	pset(sl,1, 7)
	pset(sr,1, 7)
	line(sl,hudy,sr,hudy, 7)
	pset(sl,hudy-1, 7)
 pset(sr,hudy-1, 7)
 
 draw_score(pl.score)
 if extra_score then
  local t=time()
 	--local age=t-extra_score[4]
 	if t-extra_score[4]<extra_score_expire then
		 draw_score(extra_score[1], extra_score[2],extra_score[3], true)
		else
		 extra_score=nil
		end 
 end
 
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
		local x,y=wxtoc(laser[1]), laser[2]
		local age=(t-laser[4])/laser_expire
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
	
--		if debug_kill then
--		 local off=((age * laser_size) * laser_rate)
--			line(
--			 x+(off)*laser[3],
--				y-1,
--				x+(
--				 		off
--			 		) * laser[3], 
--	  	y-1, 
--	  	15
--			)					
--			--printh(age.." "..x.."("..laser[1]..") "..off*laser[3])	
--		end	
	end

	if pl.hit~=nil and demo.t==0 then
		local age=t-pl.hit
		--printh("player dying "..age)
		if age>player_die_expire then
			pl.hit=nil	
 		reset_enemies()  -- hide and respawn enemies after a period...
			--printh("player rebirth "..age)
		end
	elseif pl.birth~=nil then
		local age=t-pl.birth
		--printh("player being born "..age)
		if (age>player_birth_expire) pl.birth=nil	
	else
		local x=wxtoc(pl.x)
		spr(2, x, pl.y, 1,1, pl.facing==-1)
		spr(32+(pl.thrusting and 0 or 16)+pl.thrusting_spr, x-(8*pl.facing), pl.y, 1,1, pl.facing==-1)
--		if pl.thrusting then
--			spr(32+pl.thrusting_spr, x-(8*pl.facing), pl.y, 1,1, pl.facing==-1)
--		else
--			spr(48+pl.thrusting_spr, x-(8*pl.facing), pl.y, 1,1, pl.facing==-1)
--		end

--		if debug_kill then
--			rect(x, pl.y+(8-pl.h)/2, x+pl.w, pl.y+8-(pl.h/2), 15)
--			if debug_kill and debug_data then
--				line(wxtoc(debug_data[1]), debug_data[2],  
--									wxtoc(debug_data[3]), debug_data[4], 12)						
--				rect(wxtoc(debug_data[1]), 
--									debug_data[2],
--									wxtoc(debug_data[1])+debug_data[5], 
--									debug_data[2]+debug_data[6], 
--									10)
--			end
--		end		
	end
end

function draw_enemies()
	local t=time()
	for e in all(actors) do
		if e.hit~=nil then
			--local age=t-e.hit
			-- todo if dying? cleared elsewhere?
			if (t-e.hit>enemy_die_expire)	e.hit=nil
		else
			local x,y=wxtoc(e.x),e.y
			local fx=(e.k==human and e.dx>0)
 		spr(e.k+e.frame,x,y, 1,1, fx)
			if not(e.k==bullet or e.k==mine) then
	 		e.t+=1
	 		if e.t%12==0 then
	 		 if (e.k~=human or (e.t%48==0 and abs(e.dx)>0)) e.frame=(e.frame+1)%e.frames
	 		end
	 		if demo.t~=0 and e.dy==0 and y~=hudy+demo_ty and e.k~=human then
					print(e.name,x-((#e.name/2)*3)+4,y+10, 5)		
					print(e.score,x-(((#tostr(e.score)+1)/2)*3)+6,y+17, 5)		
	 		end
			end
			
--			if debug_kill then		 
--		 	 rect(x+e.dx+e.xl, e.y+e.dy+e.yt,
--		 	 					x+e.dx+e.xr, e.y+e.dy+e.bt, 15) 
--	 	end

		end
	end
end

function draw_particles(alt_cycle)
	local t=time()
	local occ,cc_freq = 5,0.2
	if (alt_cycle) occ,cc_freq = 10,0.05
	-- palette cycle - as good a place as any
 if t-pt>cc_freq then
  if not epi_friendly then
	  cc=(cc%15)+1
		end
	 pal(occ,cc) -- todo true?
	 pt=t
 end
 
	for e in all(particles) do
		local x,y=wxtoc(e.x),e.y
		local c=e.c
		--local age=t-e.t
		if (t-e.t>old_particle) c=9
		pset(x,y,c)	
	end
end

function draw_stars()
	for star in all(stars) do
	 if not(humans<=0) and star[2]>lmax then
	  -- not null space and star behind ground level
	 else
 	 local cxp=cx/star[3] -- cx for screen; /star[3] for move-delay
			local x=star[1]-cxp  
			local col=5
			if cx+128>ww then
				if star[1]-cxp<(128-(ww-cx)) then
	 			x=(star[1]+(ww/star[3]))-cxp
					col=14  --new or fade depending on dir
				end
	
				if star[1]>((ww/star[3])-128) then
	 			if col==14 then
	 				--all! how!? 
	 				--col = 11  --new+fade?
	 			else
						col=12  --fade or new depending on dir
					end
	 		end
			end

			if (col~=5) col=5
			
			pset(x,star[2],col)
		end
	end
end

function animate_camera()
 -- e.g. player reversing
	-- assumes canim>0
	canim-=1
	cx=(cx+canim_dx)%ww

	-- todo remove	
	--pl.x -= canim_dx

	-- in screen space to handle any wrapping
	local x=wxtoc(pl.x) 
	if x<20 then
		--printh("!plx<20 "..x)
 	pl.x=(cx+20)%ww
 	canim=0
	elseif x>100 then  -- assumes <128, if not we're off camera and will jump
		--printh("!plx>100 "..x)
	 pl.x=(cx+100)%ww
	 canim=0
	end
	-- note: player wrap done via %	
end

function _draw_game_over()
 cls()
 
	draw_stars()

	draw_hud()

	draw_ground()

	draw_enemies()
	draw_particles()

	print("game over", 48, hudy+40, 5)
end

function _draw_title()
 cls()
 
	draw_particles(true)

	-- never expire! draw_player()  -- needed to expire

	map(0,1, 25,hudy+1, 10,4)

	print("by", 59, hudy+40, 7)
	print("greg gaughan", 39, hudy+46, 7)
	
	local o = hudy+60 + 18

	-- note: player one only?
	print("⬆️ UP  ⬇️ DOWN", 36, o, 15)
	print("❎ FIRE ➡️ THRUST", 30, o+6, 15)	
	print("⬅️ REVERSE 🅾️ BOMB", 28, o+16, 1)	
	print("⬆️⬇️🅾️ HYPERSPACE", 30, o+22, 1)
	
	print("press ❎ to start", 30, o+32, 10)
end

function _draw_highscores()
 cls()

	draw_score(pl.score)
	-- todo remove: why extra_score here?
-- if extra_score then
--  local t = time()
-- 	local age = t - extra_score[4]
-- 	if age < extra_score_expire then
--		 draw_score(extra_score[1], extra_score[2],extra_score[3], true)
--		else
--		 extra_score = nil
--		end 
-- end

	draw_particles()

	-- never expire! draw_player()  -- needed to expire

	map(0,1, 25,0, 10,4)

	print("hall of fame", 39, hudy+24, 5)

	print("todays", 10, hudy+32, 5)
	print("all time", 82, hudy+32, 5)
	print("greatest", 6, hudy+38, 5)
	print("greatest", 82, hudy+38, 5)
	-- todo underlines

	for hst=today,alltime do
	 local co=(hst-1)*76
		for i,hs in pairs(highscores[hst]) do
			local y=hudy+40+i*6
 		print(i, 1+co, y, 5)
		 if hs[1]~=nil then
				print(hs[1],10+co,y,5)
				draw_score(hs[2],24+co,y)
			end
		end
	end
end

function _draw_new_highscore()
 cls()

	draw_score(pl.score)
 
	draw_particles()

	-- never expire! draw_player()  -- needed to expire

	print("player one", 56, hudy+1, 2)
	print("you have qualified for", 16, hudy+16, 2)
	print("the defender hall of fame", 16, hudy+24, 2)

	print("select initials with ⬆️/⬇️", 16, hudy+36, 2)

	print("press fire to enter initial", 16, hudy+48, 2)

	-- todo mention bomb to backspace?

	for ci=1,#hs_name do
 	print(sub(hs_name,ci,ci), 54+ci*10, 80, 2)
 end
 local ci=#hs_name+1
	print(hs_chr, 54+ci*10, 80, 2)
	-- underlines
	for ci = #hs_name+2,3 do
 	line(54+ci*10, 88, 54+ci*10+3, 88, 2)
 end

end

function _draw_instructions()
 cls()

	draw_hud(true)  -- note: includes extra_score

	draw_ground(true)
	
	draw_enemies()
	draw_particles()

	draw_player()  -- demo.t checked to avoid dying/reset (because p.hit is overused as a timer here)
 
	print("scanner", 51, hudy+4, 5)

	-- note: animation steps via update
end

function _draw_end_wave()
 cls()
 
	draw_hud()
	draw_player()  -- needed to expire

	rectfill(0, hudy+1,127,127, 0)
	print("attack wave "..(iwave+1), 40, hudy+20, 5)
	print("completed", 46, hudy+28, 5)
	print("bonus x "..100*min(iwave+1,5), 43, hudy+48, 5)
	for h=1,humans do
		spr(human,33+h*5, hudy+56)
	end

	if pl.hit==nil then
		-- note: already increased score
		reset_player()
	 
		iwave+=1
		load_wave()
		-- prime the spawning
		local t=time()
		wave.t_chunk=t-wave_progression+wave_reset  -- reset

		_draw = _draw_wave
	end
end

function _draw_wave()
 local t=time()

 if bombing_t~=nil then
		local age=t-bombing_t
		if age<bombing_e then
	  if not epi_friendly then
			 if flr(age*18)%2==0 then
					cls(bombing_c)
				else
					cls(0)
				end
			-- else todo camera shake instead/as-well?
			end
		else
			bombing_t=nil
			bombing_e=bombing_expire  -- reset to default
		end
	else
		cls()
	end

 if (canim>0) animate_camera()

	draw_stars()

	draw_hud()

	draw_ground()

	draw_enemies()
	draw_particles()

	draw_player()

--todo reinstate		
	if debug then
--		print(cx,1,120,1)
--		print(pl.x,48,120)
--		--print(cdx,1,6)
		--if cx + 128 > ww then
		--	print("★",1,13)
		--end
		print(#actors,100,0)
		print(#particles,100,6)
--		assert(humans<=max_humans)
--		print(humans,120,0)
--		print(iwave+1,120,6)
	end
end

-->8
--build world

function build_world()
 local t=time()
 -- note: 3+4+ -> 3+1-4+ etc.
	local wd=[[
	 5+3+2-2+2=4+2=2+2-2=4+2-2+3+2-2+3+2+4+5+2=2-2-2+3-2=3+4=2+3-7+7+2=
	 7-4-7-4=4-4-3-3+4-2+5-2+2=3-2+3+2-2+3-4=6=3-4=2-10=2-48=2+8=
	 3+36=2+10=4-14=3+2+2-3+2=2-6+3-2+2+4-2+3-3-6=2-2+2+2+2+4=2+4=3-4-2+3-3+4=6-2=4+4+4=4+5-2=4+3+2=4+2-4=2-2+4=2+5-2+8-
	 18=2+4=3-18=6=20+20-10=6+6-24=5+5-12=
	 7+7-6=20+20-6=9+7-12=4+4-10=
	 6-14+8-10=4+8-20+14-4+6-10=3-
	 20=4=2+10=2+4=4+12=6+6-4+4-6+2-6=8+20-
	 5+2+2+4=2-2-2-2-2-2=2+2+2+2+2=2-2+3-2-
	 2+3+2+2+3-2-3-2+2=2-4+5-3-3-
	 4+4-2-4+3-2+4=4-5+2-3+1=7-5=
	]]
	local s,c="",""
	local n,ll=nil,nil
	local ld,d=nil,"="  -- -down, ="flat"(-+), +up
	local dy,l,wi=1,1,1
	for si=1,#wd do
		c = sub(wd,si,si)
		if not(c=="+" or c=="-" or c=="=") then
			s=s..c
		else
			n=tonum(s)
			ld=d
			d=c
			s="" -- reset
			if ld==d then
		  -- insert gap
				l=l+(dy*-1)
				w[wi]=127-l	
				wi+=1  
			end
			for j=1,n do
				if d=="+" then
				 dy=1
				elseif d=="-" then
				 dy=-1
				elseif d=="=" then
					dy*=-1
				end
				-- note: no error checking (lmin/lmax)
				l=l+dy
				w[wi]=127-l	
			
				wi+=1	
			end
		end
	end
	--printh("end w:"..wi.." at level "..l.." took "..time()-t)
	-- pre-calc for scanner				
	for wi=1,ww do	
	 if wi%hwr==0 then
		 l=127-w[wi]
		 -- todo hardcode any holes?
   ls=ll
   ll=ceil(l/hhr)  
   if ls and abs(ll-ls)>1 then
    -- patch any holes
    ll=ll+sgn(ll-ls)*-1
   end
	 	sw[wi\hwr]=hudy-ll
	 end
	end	
end

function add_stars()
	for s = 1,max_stars do
		add(stars, {
		 -- note: we add some behind the ground level but don't draw them unless null space
			rnd(ww), rnd(120-hudy)+hudy, 
			rnd(2)+10  -- parallax depth
		})
	end
end

function make_actor(k, x, y, hit)
 local at = attrs[k]
 local a={
 	k=k,
 	c=at[2],
  x=x,
  y=y,
  dx=0,
  dy=0,
  frame=0,
  t=0,  -- used as frame step or birth time for bullets/mines which have no frames
  frames=at[5],
  w=at[3],
  h=at[4],  
  
  lazy=0,
  hit=hit,
  score=attrs[k][1],
 }
 -- todo perhaps skip if bullety
 -- note flr top and right - see sprite placements
 a.yt=flr((8-a.h)/2)
 a.yb=8-a.yt 
 a.xl=ceil((8-a.w)/2)
 a.xr=8-a.xl
 
	-- todo if hit player - move
 add(actors,a)
	return a
end

function add_bullet(x, y, from, track)
 -- note: also creates mines
 local t=time()
	b=make_actor(bullet,x,y)
	local bv = bullet_speed
	if (from and from.k==baiter) bv *= 1.6
	-- todo for some, hang around player?
	local tx,ty=pl.x,pl.y  -- aim at player
	-- todo if bad aimer, add miss (slow bv does this to some extent)
	if track then
	 -- todo also take account of e.dy
	 local proj_speed=bv+from.dx  -- todo remove from.dx?
	 local pldx=cdx*pl.facing
		local ta=pldx*pldx+pl.dy*pl.dy-proj_speed*proj_speed
		local tb=2*(pldx*(pl.x-b.x)+pl.dy*(pl.y-b.y))
		local tc=(pl.x-b.x)*(pl.x-b.x)+(pl.y-b.y)*(pl.y-b.y)
		local disc=tb*tb-4*ta*tc
		if disc>=0 then
			local t1=(-tb+sqrt(disc))/(2*ta)
			local t2
			if disc~=0 then
				t2=(-tb-sqrt(disc))/(2*ta)
			else
				t2=t1
			end
			local tt=t1
			if (tt<0 or (t2>tt and t2>0)) tt=t2
			if tt>0 then
				tx=tt*pldx+pl.x
				ty=tt*pl.dy+pl.y
				--if (debug)	printh("quadratic solved:"..tt.." ("..pldx..") -> "..tx..","..ty.." instead of "..pl.x..","..pl.y)
			 -- else none +ve (can't fire back in time)
			end	
		-- else no discriminant, forget it - todo perhaps undo fire?
		end
	end
 -- todo here: add miss-factor!
 -- done?-- todo here: add slowdown factor/rate for non-track (landers etc.)
	b.dx=(tx-b.x)*bv
 b.dy=(ty-b.y)*bv
	b.t=t
	if from and from.k==bomber then
		b.k,b.c=mine,5
		b.dx,b.dy=0,0	
	end
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
	reverse=reverse or false
	speed=speed or particle_speed
	expire=expire or particle_expire
	local t=time()
	local f=0
 for i=1,16 do
  -- todo make some faster
  local x,y=e.x+4,e.y+4  -- todo h/w better?
  local s=speed
  local d=sp[i]
  if d[1]==0 or d[2]==0 then
			if (f==0) s=particle_speed*0.8
  	f=1-f  --prevent for next one
  end
  if reverse then
  	x+=d[1]*30
  	y+=d[2]*30 
  	d[1],d[2]=-1*d[1],-1*d[2]
  end
		add(particles,{
			x=x,y=y,
			dx=d[1]*s,dy=d[2]*s,
			c=e.c, t=t, expire=expire,
		})
	end
end

function kill_actor(e, laser, explode)
 local t=time()
	if (explode==nil) explode=true
	--print("explode "..tostr(explode))
 if explode then
		if not(e.k==bullet or e.k==mine) then
		 add_explosion(e)
	 	if (laser) del(lasers,laser)  -- i.e. allow to hit something else after a bullet
 	 -- note: may have already been expired elsewhere		
	 end
	end

	del(actors, e)
	--printh(e.k.." dead "..e.x)			 	
	
	if demo.t==0 then
		add_pl_score(e.score)
		
		if e.k==lander then
		 sfx(1)
		 wave.landers_hit+=1
		 
		 if e.target~=nil then
			 if e.target.capture==capture_lifted then
			 	-- todo set drop time / score depending on height/landing
			 	--printh("drop human!")
			 	e.target.dy=gravity_speed
					e.target.dropped_y=e.y
			 	e.target.capture=nil
			 	sfx(5)
			 end
			end
		 
		 -- note: could have just added a batch! todo fifo?
		 if wave.landers_hit%5==0 then
				if (wave.landers>0) add_enemies()
			end
		elseif e.k==mutant then
		 wave.landers_hit+=1  -- same as lander since we can compare with spawn number 1 for 1
			-- todo track separate hits too?
		elseif e.k==baiter then
		 wave.baiters_generated-=1  -- i.e.so max_baiters => max active batiers
			-- todo count baiters_hit - why not
		elseif e.k==bomber then
		 wave.bombers_hit+=1
		elseif e.k==pod then
		 wave.pods_hit+=1
		 -- todo sfx(?)
		 -- spawn swarmers
		 local r=flr(rnd(256))
		 local make=7 -- 172..255
		 if r<64 then
		  make=4
		 elseif r<128 then
		  make=5
			 if (r==65) make=1
		 elseif r<172 then
		  make=6
			 if (r==129) make=2
		 end
		 if (r==173) make=3
		 make=min(make, max_swarmers-wave.swarmers_generated)
		 for sw=1,make do
			 local x,y=e.x+rnd(3),e.y+rnd(6)
				l=make_actor(swarmer,x,y)  -- no time = show immediately
				l.dy=swarmer_speed/2
				if (rnd()<0.5) l.dy*=-1  
				-- don't go towards player at first: l.dx = swarmer_speed
				-- if (rnd()<0.5) l.dx *= -1
				l.lazy=rnd(64)  -- higher = less likely to chase
				-- todo sfx(?)  -- todo: if on screen
			end
			wave.swarmers_generated+=make
		elseif e.k==swarmer then
		 wave.swarmers_generated-=1  -- i.e.so max_swarmers => max active swarmers
			-- todo count swarmers_hit - why not
		elseif e.k==human then
			--printh("dead human "..e.x)
		 -- todo wrap in kill_human routine?
			if e.capture~=nil then
		  --printh("dead human had been captured "..e.x.." "..e.capture)
		  -- reset any lander that had this as a target (else picks up a phantom)
		 	for a in all(actors) do
		 		if (a.k==lander and a.target==e) a.target = nil
 	 			--printh("unlinking target after human dead "..a.target.x.." "..a.x) 			
		 			-- todo find a new one! (not in pl.target)
		 	end
			 for plt in all(pl.target) do
		 		if (plt==e) del(pl.target,plt)
		 			--printh("unlinking player target after human dead "..plt.x.." "..pl.x)
		 	end
			end
		 humans-=1
			--printh(" humans left "..humans)
		 if humans<=0 then
		 	-- null space
		 	-- todo camera shake?
				--	explode planet!
		  local s=particle_speed/1.5
		  local d={rnd()-0.5,-1}
				for sx=-64,192 do
					local i=((ceil(cx+sx))%ww)+1
			  local x,y=cx+sx,w[i]  
			  if (rnd()<0.08) d,s={rnd()-0.5,-1},s+rnd()/6
					add(particles,{
						x=x,y=y,
						dx=d[1]+(abs(sx)/256)*s,dy=d[2]*s,
						c=4, t=t, expire=ground_destroy_expire,
					})				
				end
		 	music(8,0,8)  -- review last 8 = channel 3 reserve
		 	-- convert any existing landers to mutants
		 	for a in all(actors) do
		 		if a.k==lander then
		 			--printh("converting lander to mutant after null space (all humans dead) "..a.x)
		 			a.k=mutant
			 		a.lazy=0  -- todo or remove altogether?
						a.dy=mutant_speed*lander_speed_y_factor
		 		end
		 	end
				wave.mutants+=wave.landers
				wave.landers=0
		 	-- also any further landers will be mutants - even on later levels until humans are replenished
		 	bombing_c=5
		 	bombing_e=ground_destroy_expire
		 	bombing_t=time()
			end
		 -- todo if no more landers/mutants (based on hit counts?) then kill all baiters? - no need since is_wave_complete will be true
		end
		if is_wave_complete() then
		 pl.hit=time()  -- pause
		 add_pl_score(humans*100*min(iwave+1,5))
			_draw=_draw_end_wave
		end
	else 
		-- demo mode
	 bombing_t=t
		demo.step_next_part+=1
	end
end

function reset_player(full)
 if full then
		pl.lives=2  -- plus start life = 3
		pl.score=0
		pl.score_10k=0
		pl.bombs=3
		-- note: no birth set
 end
 cdx=0 -- freeze  
 -- todo reset cx? bombing_t etc.
 bombing_e=bombing_expire
	pl.x=cx+20
	pl.y=64
	pl.facing=1  -- todo need camera move?	
	pl.dy=0
	pl.thrusting=false
	pl.target={}
	pl.birth=nil
end

function kill_player(e)
 pl.hit=time()
	sfx(3,-2)
	sfx(4)
	wave.t_chunk-=player_die_expire  -- don't include dying time
 cdx=0 -- freeze
 for i=1,16 do
  local d=sp[i]
	 pl.x+=d[1]*rnd(4)
	 pl.y+=d[2]*rnd(4)
	 add_explosion(pl, false, rnd(particle_speed)+0.1, player_die_expire)
	end 
	--note: pl x/y adjusted - don't bother to restore since we're dying
	--printh(#particles)
	pl.lives-=1
	add_pl_score(25)
	
	-- todo maybe reset_player() here (if so lose cdx = 0 above)
	
	--printh("player killed by "..e.x)
	kill_actor(e, nil, false)  -- no explosion
	
 for plt in all(pl.target) do
		--printh("player was carrying human - also killed "..plt.x)
		kill_actor(plt, nil)
		del(pl.target,plt)
		-- assume shot - not technically killed by falling from a height?
	end

	if pl.lives<0 then
	 pl.hit=time()  -- pause
		_draw=_draw_game_over
		_update60=_update60_game_over
	end

	--note reset_enemies() will be called during draw (i.e. after death animation)
end

function add_humans()
 -- todo pass in t?
 if debug then
	 local hc=0
		for e in all(actors) do
			if (e.k==human) hc+=1
		end
		if (hc~=0) assert(hc~=0)
			--printh(humans.." "..wave.t)
	end

	for h=1,humans do
	 local x=rnd(ww)  -- todo groups?
	 local y=120-flr(rnd(4))
		h=make_actor(human,x,y,time())
		h.dx=rnd(human_speed)  
		if (rnd()>0.5) h.dx=h.dx*-1
		-- todo rnd frame?
		h.capture=nil
		h.dropped_y=nil
	end
	--printh("added "..humans.." humans") -- replenish on 1st wave update
	add_humans_needed=false
end


function active_enemies(include_only)
 -- don't count baiters (and include_only, if given)
 -- don't count bullet,mine,human
 -- does count swarmers (wave.swarmers_generated) - though level restart not required if only swarmers remain - todo:ok?
 local r=0
	for e in all(actors) do
	 if (include_only and e.k~=include_only) then
	   -- ignore
	 else
	  if (not(e.k==baiter or e.k==bullet or e.k==mine or e.k==human)) r+=1
	 end
 end
 return r
end

function is_wave_complete()
	local r=0
 -- spawned (except generated baiters)
 r+=active_enemies()
	-- plus yet to spawn
	r+=wave.landers
	r+=wave.bombers
	r+=wave.pods
	-- todo? swarmers	
	-- note: baiters not counted towards completion
	-- note: mutants don't spawn initially but they accrue during play
	r+=wave.mutants  
	--printh("r="..r)
	--printh(wave.landers_hit)
	return r==0  -- i.e. no more left
end

function load_wave()
	local t=time()
	local sw=waves[iwave%8+1]
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
	wave.baiters_generated=0
	wave.swarmers_generated=0

	if iwave==0 or ((iwave+1)%5==0) then
  -- replenish
		wave.humans_added=max_humans-humans
		humans+=wave.humans_added
		-- todo: use humans_added to avoid re-adding (update: we now do this via add_humans_needed)
		assert(humans<=max_humans)  --todo remove
		--printh("adding humans "..wave.humans_added.."="..humans)
	end
	
 if humans<=0 then
  -- null space
 	wave.mutants+=wave.landers
 	wave.landers=0
 end
 
	if	debug_test then
		--wave_old = 1
		--wave_progression=1
		wave.landers=2 --1 --breaks null space
		wave.mutants=0
		--wave.bombers=min(1,wave.bombers)
		--wave.pods=min(1,wave.pods)
	end
end

function add_enemies(ht)
 -- note: pass in ht to override make_actor hit time
 if (ht==nil) ht = time()
 local t=time()
 local sound=not(ht>t) -- if ht>t we don't fire sfx - i.e. assume game starting music is playing
 -- see reset_enemies for undo
 local make
	if wave.landers>0 then
	 make=min(wave.landers,5)
		for e=1,make do
		 local x=rnd(ww)
		 local y=hudy+2
		 -- todo if hit player - move
			-- note: pass hit time = birthing - wait for implosion to finish  note: also avoids collision detection
			l=make_actor(lander,x,y,ht)
			l.dy=lander_speed*lander_speed_y_factor
			l.lazy=rnd(512)  -- higher = less likely to chase
			--l.h=5
			--l.w=7
			--todo remove l.score=150	
			--l.frames = 3
			-- find a target
			l.target=nil
			if true then --humans > 0 then
				for i,a in pairs(actors) do
					if a.k==human and a.capture==nil and a.dropped_y==nil then
					 -- todo perhaps skip or move if on/near wrap-line
		 			-- note: e.capture==nil implies not in pl.target, i.e. player not carrying
		 			--       *but* could be falling so we now check dropped_y==nil too
		 			-- todo: though might be funny to have lander steal human from player!
						l.target=a
						l.target.capture=capture_targetted
						--printh(l.x.." targetting "..i.." = "..a.x)
						break
					end
				end
			end
			add_explosion(l,true)  -- reverse i.e. spawn
			if (sound) sfx(2)  -- todo: if on screen
		end
		wave.landers-=make
	end
	if wave.mutants>0 then
	 make=wave.mutants
		for e=1,make do
		 local x,y=rnd(ww),hudy+2
		 -- todo if hit player - move
			-- note: pass hit time = birthing - wait for implosion to finish  note: also avoids collision detection
			l=make_actor(mutant,x,y,ht)
			l.dy=mutant_speed*lander_speed_y_factor
			-- todo remove lazy here?
			l.lazy=rnd(512)  -- higher = less likely to chase
			--l.h=5
			--l.w=7
			--todo remove l.score=150	
			add_explosion(l, true)  -- reverse i.e. spawn
			if (sound) sfx(2)  -- todo: if on screen
		end
		wave.mutants-=make
	end
	if wave.bombers>0 then
	 make=min(wave.bombers,3) -- ok?
	 local groupx=rnd(ww)
	 local groupdx=1
		if (rnd()<0.5) groupdx*=-1
		for e=1,make do
		 local x=groupx+rnd(ww/20)
		 local y=hudy+2+rnd(80)
		 -- todo if hit player - move
			-- note: pass hit time = birthing - wait for implosion to finish  note: also avoids collision detection
			l=make_actor(bomber,x,y,ht)
			l.dy=bomber_speed
 		if (rnd()<0.5) l.dy*=-1
			l.dx=groupdx*bomber_speed
			add_explosion(l,true)  -- reverse i.e. spawn
			if (sound) sfx(2)  -- todo: if on screen
		end
		wave.bombers-=make
	end
 if wave.pods>0 then
	 make=min(wave.pods,4) -- ok?
		for e=1,make do
		 local x,y=rnd(ww), hudy+2+rnd(30)
		 -- todo if hit player - move
			-- note: pass hit time = birthing - wait for implosion to finish  note: also avoids collision detection
			l=make_actor(pod,x,y,ht)
			l.dy=pod_speed
			l.dx=pod_speed/4
			add_explosion(l,true)  -- reverse i.e. spawn
			if (sound) sfx(2)  -- todo: if on screen
		end
		wave.pods-=make
	end
	-- based on wave.t? and/or remaining
 -- baiters, if near end of wave
 if wave.baiters_generated<max_baiters then  -- todo adjust for iwave?
		--local t=time()
		local age=t-wave.t
		if age>wave_old*2 or (wave.landers==0 and wave.bombers==0 and wave.pods==0) then
			if age>wave_old*2 or (wave.mutants==0) then -- todo: include here? active xor this i think?
				local ae=active_enemies(lander)+active_enemies(mutant) -- excludes baiters
				if ae<5 or age>wave_old*2 then 
					if age>wave_old then  -- todo adjust for iwave?	2,3,4+ need more time?		
					 make=1 -- remove: 5-ae 
					 if ae<4 then
							-- prime next one sooner
							wave.t_chunk=t-wave_progression+baiter_next*ae
							--printh(ae.." enemies left so priming next baiter respawn for "..wave.t_chunk.." at "..t)
						end			 
						for e=1,make do
						 local x,y=rnd(ww),hudy+2
							-- note: pass hit time = birthing - wait for implosion to finish  note: also avoids collision detection
							l=make_actor(baiter,x,y,ht)
							l.dy=baiter_speed/3
							l.lazy=-256  -- higher = less likely to chase
							add_explosion(l,true)  -- reverse i.e. spawn
							if (sound) sfx(2)  -- todo: if on screen
							--printh("new baiter "..l.x)
						end
						-- note: not counted as part of wave: re-generate as needed based on enemies left/wave.t
						wave.baiters_generated+=make
					end		
			 end
			end
		end
	-- else max_baiters reached
	end
end

function	reset_enemies()
	-- undo add_enemies/add_humans
	-- push active enemies back on wave and setup re-spawn
	t=time()
	for e in all(actors) do
		-- todo check not just hit?
		if e.k==lander then
			wave.landers+=1
		elseif e.k==mutant then
			--todo old: note: no need: already added on conversion: 
			wave.mutants+=1
		elseif e.k==bomber then
			wave.bombers+=1
		elseif e.k==pod then
			wave.pods+=1
		--elseif e.k == human then
		--	-- accounted for by humans var
		--elseif e.k == baiter then
		--	-- not counted: re-generate as needed
		--elseif e.k == swarmer then
		--	-- not counted: re-generate as needed
		--elseif e.k == bullet then
		--elseif e.k == mine then
		--else -- todo remove
		--	assert(false, "unknown e.k:"..e.k)		
		end
		del(actors, e)  -- note: we don't retain the positions on respawn!
	end
	wave.baiters_generated=0
	wave.swarmers_generated=0
	add_humans_needed=true
	-- prime the respawning
	wave.t_chunk=t-wave_progression+wave_reset  -- reset
end

function enemy_attack(e) 
	-- todo wrap?
 local fire=(e.k==bomber or (abs(e.x-pl.x)<128))  -- bomber lays mines
	if fire then   
	 -- todo move rnd to table

	 -- todo elseif more efficient	- no: rnd-lookup first
		if ((e.k==lander) and (wxtoc(e.x)>128 or wxtoc(e.x)<0)) fire=false  -- off screen

		if (e.k==lander and rnd()>0.0025) fire=false
		if (e.k==mutant and rnd()>0.006) fire=false

		-- todo wrap?								
		if (e.k==baiter and (abs(e.x-pl.x)>128 or rnd()>0.015)) fire=false -- todo higher rnd?	
		if (e.k==swarmer and (abs(e.x-pl.x)>128 or not((e.dx>0 and e.x<pl.x) or (e.dx<0 and e.x>pl.x)) or rnd()>0.004)) fire=false -- todo differ rnd from mutant
					-- swarmer may not be chasing yet or chasing but gone past so stop firing (todo:for now)

		if (e.k==bomber and rnd()>0.005) fire=false
		
		if fire then		
			local this_sound=(sound and e.k~=bomber)
			-- move sfx # to table (and allow none)
		 if (this_sound) sfx(7)  -- todo not if baiter? why? another sound!? also for swarmer
			b=add_bullet(e.x, e.y, e, (e.k==baiter))  -- todo pass weak=true for lander
		end	
	end		
end


function load_highscores()
	if cart_exists then
	 -- note: 8 slots hardcoded here
		-- note: bytes 0+1 for future use
		for hs=1,8 do
			local name=nil  -- i.e. stored as 0
			local hso=0x5e00+(hs*2*4)
   -- todo @ instead of peek
			local c1=peek(hso+0) 
   local c2=peek(hso+1)
			local c3=peek(hso+2)
			--local c4=peek(0x5e00 + (hs*2)*4+3)
			-- todo assert c4==0
			if c1~=0 or c2~=0 or c3~=0 then
				name=chr(c1)..chr(c2)..chr(c3)
				--printh("!"..name.." "..c1..c2..c3)
			-- else ?assert score==0
			end
			local score=dget(hs*2+1)
			if (score~=0) add_highscore(score,name,false)
			-- else empty cart (first run) or nothing saved here yet
		end 
	else
 	--printh("skipped dget: not cart_exists")
	 -- todo: better score + add via add_highscore to ensure they're kept in order!
	 highscores[alltime][1]={"gjg", 21270>>16}
	end
  
	-- todo reinstate!
--	if debug then
--	 local hste = highscores[today]
--	 hste[1]={"gjg", 21270>>16}
--	 hste[2]={"g2g", 11270>>16}
--	 hste[3]={"g3g", 1270>>16}
--	 hste[4]={"g4g", 270>>16}
--	end
end

function add_highscore(score, name, new)
	-- assumes caller already knows we have a highscore (e.g. checked against [8])
	-- pass new=false if loading from cdata, i.e. don't try to store = cycle!
	if (new==nil) new=true
	local start_board=today
	if (not new) start_board=alltime  -- don't load cart/alltime into today
 -- find position 
 for hst=start_board,alltime do
 	-- todo short-circuit if not possibly in alltime, based on today pos
	 local pos=#highscores[hst]  -- i.e. 8
	 while pos>0 and score>highscores[hst][pos][2] do
		 pos-=1
	 end
	 if pos~=#highscores[hst] then
		 if pos>=0 then
		 	-- push others down
		 	for hs=#highscores[hst],pos+2,-1 do
			 	highscores[hst][hs]=highscores[hst][hs-1]  -- copies name+score
		 	end
		 	-- insert
 		 -- todo >>16 here? or caller?
		 	highscores[hst][pos+1]={name, score}
		 	
		 	if hst==alltime and new then
					--printh("writing alltime highscore to cart "..name..":"..score.." at "..pos+1)
					if true then -- todo remove: cart_exists then
					 -- note: 8 slots hardcoded here
						-- note: bytes 0+1 for future use
						for hs=1,8 do
							local hso=0x5e00+(hs*2*4)
						 local hs_name=highscores[hst][hs][1]
						 local name_bytes=0  -- i.e. nil = not set
						 if hs_name ~= nil then
							 poke(hso+0, ord(sub(hs_name,1,1))) 
        poke(hso+1, ord(sub(hs_name,2,2)))
								poke(hso+2, ord(sub(hs_name,3,3)))
								poke(hso+3, ord(chr(0)))
								--printh("!"..hs_name.." "..name_bytes)
							end
							dset(hs*2+1, highscores[hst][hs][2])
						end 			 
					else
						--printh("failed dset: not cart_exists")
					end
		 	end
		 -- else assert
		 end	
		-- else assert? caller shouldn't have called us
		end
	end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000bb000000bb00000099b00000b9900000bbb0000000000000000000000000000000000
00700700000000000660000000000000000000000000000000000000000fb000000fb00000b0b0b000b0b0b000bb0bb000000000000000000000000000000000
0007700000000000e66600000000000000070000000000000000000000022e0000022e000009b9000009b900000bbb0000000000000000000000000000000000
00077000000000006e66659000000000000075000000000000000000000e2e00000e2e0000b0b0b000b0b0b000b0b0b000000000000000000000000000000000
007007000d000000eee6666b00000000000700000d0000000000000000040000000440000b00b00b0b00b00b0b00b00b00000000000000000000000000000000
00000000dddd1900000000000000000000000000eed5000000000000000400000004400000000000000000000000000000000000000000000000000000000000
000000000e73dd730000000000000000000000000edd300000000000000000000000000000000000000000000000000000000000000000000000000000000000
50505005550500550055050505055055505550505055555057755555555555550000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550000000000055b0000055b0000055b0000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550000000000b55eb000b55eb000b55eb000000000000000000000000000000000
555555555555555555555555555555555555555555555555555555555555555500077000000e2e00000e2e00000e2e0000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550007700000b040b000b040b000b040b000000000000000000000000000000000
5555555555555555555555555555555555555555555555555555555555555555000000000b00400b0b00400b0b00400b00000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000bbbbb000bbbbb000bbbbb000000000000000000000000000000000
000b7b88000097e8000b0970000897b800000000000000000000000000000000000000000b80808b0b80808b0b08080b00000000000000000000000000000000
0099078e007b789000787eee00b0877800000000000000000000000000000000000000000ba0a0ab0b0a0a0b0b0a0a0b00000000000000000000000000000000
00007700000000e90000097000009900000000000000000000000000000000000000000000bbbbb000bbbbb000bbbbb000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000b00000000000000000000000000000000000000000000eee00000000000000000000000000000000000000000000000000
00000908000007e80000097000000778000000000000000000000000000000000000000000555e0000555e000055500000000000000000000000000000000000
0000077e0000087000000eee000009000000000000000000000000000000000000000000005a5e00005a5e00005a5e0000000000000000000000000000000000
0000070800000000000000000000000000000000000000000000000000000000000000000055500000555e0000555e0000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000eee0000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000050a05000a050a0005050500050a050000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000e5e000005e500000e5e000005e500000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000005e5e5e5055e5e550ae5e5ea055e5e55000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000e5e000005e500000e5e000005e500000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000050a05000a050a0005050500050a050000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000088800000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000008b8b80000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000088800000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000050500000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000050500000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000aa000a00aaa000aa00000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000a8aa0aa0aa8aa0aaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000a88aa0a80aa8aa0aa8aa000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000aaaaa8aa8aaa0880aa88aa00000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000aa8888aaa8aaa00008aa88aa0000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000aa88880aa88aaa00aa8aa88aa0000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000aa88000aaa80aaaaaaa08aaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000aaa80000aaa808aaaaa8088aaa80000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000008888000088880888888800888880000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000008880000088800088888000088800000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000aaaaa00aaaaaa0aaaaaa0aaaaa0aa0000a00aaaaaa00aaaaa0aaaaa00000000000000000000000000000000000000000000000000000000000000
0000000000aaaaaa00aaaaa80aaaaa00aaaaa0aaa000aa8aaaaaaa8aaaaaa8aaaaa0000000000000000000000000000000000000000000000000000000000000
000000000aaa88aa0aa88888aa88880aa88880aaaa00aa8aa888aa8aa88888aa88aa000000000000000000000000000000000000000000000000000000000000
00000000aaa88aa8aa888888aa88880aa88880aaaaa0aa8aa8888aa8aa88888aa88aa00000000000000000000000000000000000000000000000000000000000
0000000aaa888aa8aaaaaa8aaaaaa0aaaaaa00aa8aaaaa88aa888aa8aaaaa88aaaaaa00000000000000000000000000000000000000000000000000000000000
000000aaa888aa8aaaaaa88aaaaa00aaaaaa00aa88aaaaa8aa8888aa8aaaaa88aaaaaa0000000000000000000000000000000000000000000000000000000000
00000aaa8888aa8aa88888aaa8880aaa888800aa888aaaa8aa8888aa8aa88888aa8aaaa000000000000000000000000000000000000000000000000000000000
0000aaa8888aa8aa888888aa88880aaa888800aa0888aaa8aaa888aaa8aa88888aa88aaa00000000000000000000000000000000000000000000000000000000
000aaaaaaaaaa8aaaaaaa8aa8880aaaaaaaaa0aa0088aaa88aaaaaaaa8aaaaaaa8aa88aaa0000000000000000000000000000000000000000000000000000000
00aaaaaaaaaa8aaaaaaa8aaa8000aaaaaaaaa0aa00888aaa8aaaaaaaa88aaaaaaa8aa88aaa000000000000000000000000000000000000000000000000000000
0aaaaaaaaaa88aaaaaaa8aa88000aaaaaaaaa0aa00088aaa8aaaaaaa888aaaaaaa8aaa88aaa00000000000000000000000000000000000000000000000000000
08888888888888888888888800008888888880880008888888888888888888888888888888800000000000000000000000000000000000000000000000000000
08888888888888888888088800008888888880880000888808888888808888888808880888800000000000000000000000000000000000000000000000000000
08888888888088888888088800008888888880880000088808888888000888888808880088800000000000000000000000000000000000000000000000000000
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
0000000000000000000202020000000000000000000000000002020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1011121314151513121716170000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
808182838485868788808a8b8c8d8e8f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
909192939495969780999a9b9c9d9e9f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0a1a2a3a4a5a6a7a8a9aaabacadaeaf00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b0b1b2b3b4b5b6b7b8b9babbbcbdbebf00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c0c1c2c3c4c5c6c7c8c9cacbcccdcecf00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d0d1d2d3d4d5d6d7d8d9dadbdcdddedf00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0e1e2e3e4e5e6e7e8e9eaebecedeeef00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0002000034634356443665436664366443663435624346243362432624306242f6142e6142c6142b6142a61429614286142761426614256142461424614236142361422614226142261423624236242462425624
000100001102011020100200e0200b020090200602002020010100000000010020200402006020090200a02009020080100601003010010000000002000030000300000000000000000000000000000000000000
000300001e6501f65020650216502265023650236502264022630216301f6201c6201a6101861016610156101361012610116100f6100f6100e6100d6100d6200d6200d6200d6200e6300f630116401364013650
000400000661007610086100861006610046100461003610036100461005610086100961009610086100761005610046100361003610056100761009610096100961008610066100561004610056100661007610
000c0000166501c66020670196601c65017630126200e6100c6200f6401165013650116400f6300c620096200861008610096100c6200d6300b630076200561006610096200c6300c6300a620066100561005610
0003000031220312303123031230312202d2202c22029220282202822027220252202421023210222102121021210202101f2001e2001e2001d2001c2001b2001b2001a2001a2001a20000200082000620005200
000200002064029650326603066021650186300b6300a630106301663022630296501d6601067007670036600b650136401a640246401e6501166004670046700b6601d6502a640286401c650126600766001660
00010000254402c450314403143020420154201342015420184300040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400
0001000022150281502b160261601b170191701a1701d15022140291302e130301402d150231601817017170171501c14022160291602f170351703b1702516018140141301513019130201301e1201312011120
0001000011150161501c1602216026140211201a12018120181301b13028130231301b110151101912011120121200e12012120121201a1102211018120131301d14025140161300c12009120061200812009120
000300003514035140351403514034140311402e1402b13026120221201e1201b12018120161401614017150191501915016140121400d1300c12000100001000c10000100001000010002100001000010000100
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400000e2500e2500e2500e2500e2500e2500e2500e2500e2500e2500e2500e2500e2500e2501125016250172401724013240102301623016230162300a2300f2300f24006240072400a2400e250102500f250
000400000d2400d2500e250072500b2500f2500f2500f2500b2500824006240062400624007250082500b2500e2500e2500e2500e2500c2500a250082500724006240062400f2400f25008250062500b2500d250
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000413006130071300713005130031200212001120011200112003120041300213000130001300013000120011200312004120031200112000130001300013001130031300412003120021200112000130
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000900001d4502145024450274502a4502b4502c450274501e45017450134501345015450194501e4502145026450244501f4501945016450104500c4500b4500c4500e4500f450124500f4500d4500e45000400
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0110000000270002700027000270002700027000270002700727007270072000727007270072000727007270122701b2301d2701f2701f2701f2501e25018250172501425012250102500e2500b2500825007250
__music__
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 08424344
00 09424344
04 06424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 10144344
04 11144344

