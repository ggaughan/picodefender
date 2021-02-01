pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- pico defender
-- ggaughan, 2021
-- remake of the williams classic

debug = true
debug_test = not debug  -- 1 of each enemy per wave
debug_kill = not debug

today = 1
alltime = 2
empty_hs = {nil,0}
highscores = {
	{empty_hs,empty_hs,empty_hs,empty_hs,empty_hs,empty_hs,empty_hs,empty_hs},
	{empty_hs,empty_hs,empty_hs,empty_hs,empty_hs,empty_hs,empty_hs,empty_hs},
}

human=7
lander=9
mutant=25
bomber=57
pod=73
swarmer=89  -- comes from pod
baiter=41  -- spawn near end of level
mine=105  -- comes from bomber
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
mutant_speed = 0.4
baiter_speed = 2.2  -- faster than player  -- todo set to max_speed*factor?
bomber_speed = 0.3
pod_speed = 0.2
swarmer_speed = 0.6
bullet_expire = 1.4  -- todo depend on actual bullet_speed?
bullet_speed = 0.02
mine_expire = 6

particle_expire = 0.8
particle_speed = 0.6
--enemy_explode_size = 32

player_die_expire = 3
old_particle = 1
enemy_die_expire = 1

human_speed = 0.02
target_x_epsilon = 1
target_y_epsilon = 3
capture_targetted = 1
capture_lifted = 2
--todo remove: set dropped_y instead: capture_dropped = 3
gravity_speed = 0.1
safe_height = 80

wave_progression = 15  -- seconds
wave_old = 60  -- min before baiters
baiter_next = wave_progression / 3  -- delay baiter re-spawn based on last 3 enemies
max_baiters = 4
max_swarmers = 20
wave_reset = 2  -- seconds

extra_score_expire = 1
bombing_expire = 0.3

title_delay = 8
title_particle_expire = 1.4
game_over_delay = 4
new_highscore_delay = 60  -- timeout if no initials in this time

function _init()
	cart_exists = cartdata("ggaughan_picodefender_1")

	w = {}  -- ground + stars
	sw = {} -- ground summary
	stars = {}
	cx = 128 * 4
 cdx = 0
 canim = 0
 canim_dx = 0

	build_world()
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
	-- todo remove: start_game does this: can't do more than once:
	--    load_wave()
	-- todo wrap iwave display to 2 digits (100 and 200 show as 0 when completed) 
	--      then actually wrap at 255 with special wave 0
	
	-- palette rotate	
	pt = time()
	cc = 1
	
	extra_score = nil
	bombing_t = nil  -- also used for title animation
	
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
	 	sfx(0)
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
	 
	 if btnp(🅾️) then 
	 	-- smart bomb - kill all enemies
	 	if pl.bombs > 0 then
		 	sfx(6)
		 	bombing_t = time()
				for e in all(actors) do
				 -- note: we kill bullets and mines too
				 -- note: original doesn't seem to...
			  if not(e.k == human) then
						local sx = wxtoc(e.x)
						if sx >= 0 and sx <= 127 then
							e.hit = t
						 kill_actor(e, nil)
						end
			  end
				end	
	 		pl.bombs -= 1
		 end
	 end
	 
	 pl.dy *= inertia_py
	 pl.y += pl.dy 
	 
	 cdx *= inertia_cx
	 cx += cdx * pl.facing
	 pl.x += cdx * pl.facing  -- note: this is effectively pl.dy
	
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
			sfx(3, -2)
		end
	 if t-pl.thrusting_t > 0.05 then
			pl.thrusting_spr = (pl.thrusting_spr+1) % 4
			pl.thrusting_t = t
		end

		if (pl.thrusting)	sfx(3)
	
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

	 if pl.target ~= nil and pl.target.capture == capture_lifted then
	 	--printh("carrying "..pl.x.." "..pl.target.x)
	 	pl.target.x = pl.x 
	 	pl.target.y = pl.y + 6
	 	-- todo dx/dy?

			if pl.target.y > 116 then
		 	printh("dropping "..pl.x.." "..pl.target.x)
		 	pl.target.dy = gravity_speed
		 	pl.target.dropped_y=pl.y
		 	pl.capture = nil
		 	pl.target = nil
		 	add_pl_score(500)
		 end
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
 	if e.k ~= mine then
			-- check if hit by laser
		 for laser in all(lasers) do 	
		  if not e.hit then
					--local actual_age = (t-laser[4]) --/ laser_expire
					local age = (t-laser[4])/laser_expire
					local x,y = laser[1], laser[2]
				 -- todo include wrap at end
				 --      or cut short draw!
					--if actual_age > laser_min_effective_age then
					if (age * laser_size * laser_rate) >= abs((e.x+(8-e.w/2))-(x+4)) then
					 -- todo precalc half widths			
					 -- todo include wrap at end
					 -- todo maybe cut off at screen/camera
						if y >= (e.y+e.dy+(8-e.h)/2) and y <= (e.y+e.dy+8-(e.h/2)) then
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
		end
		
		if not e.hit then  
			-- check if hit player
		 -- todo include wrap at end
			--local x=(e.x+flr(8-e.w)/2+flr(e.w/2)+e.dx) - (pl.x+flr(8-pl.w)/2 + flr(pl.w/2))  -- todo: precalc/hardcode player offset (2)
			--local y=(e.y+flr(8-e.h)/2+flr(e.w/2)+e.dy) - (pl.y+flr(8-pl.h)/2 + flr(pl.h/2))  -- todo: precalc/hardcode player offset (2)
			local x=(e.x+4+e.dx) - (pl.x+4)
			local y=(e.y+4+e.dy) - (pl.y+4)  
			if e.k ~= human then
				if (abs((x)*2) < (e.w+pl.w) and
						 (abs((y))*2) < (e.h+pl.h))
				then
					if debug_kill then
						pl.dx, pl.dy = 0,0
					 debug_data = {(e.x+(8-e.w)/2+e.w/2+e.dx),
					 														(e.y+(8-e.h)/2+e.h/2+e.dy), 
					 														(pl.x+(8-pl.w)/2)+pl.w/2, 
					 														(pl.y+(8-pl.h)/2)+pl.h/2,
					 												  (e.w+pl.w),(e.h+pl.h)}
					 printh(x.."<"..(e.w+pl.w))
					 printh(y.."<"..(e.h+pl.h))
					 printh(debug_data[1].." "..debug_data[3])
					 printh(debug_data[2].." "..debug_data[4])
					 _update60=_update60_debug_stop
					else
		 			e.hit = t
				 	kill_player(e)
				 end
				end
			else -- human - can we catch it?
				-- todo refine -4 = -h etc? todo wrap?
				if pl.target == nil and e.capture == nil and e.y < 116 and abs(e.x - pl.x) < target_x_epsilon * 2 and ((e.y-4) - pl.y) < target_y_epsilon*2 then
			 	-- here!
			 	printh("catching! "..e.x.." "..pl.x..":"..e.y.." "..pl.y)
			 	pl.target = e
			 	e.dy = 0 --pl.dy
			 	e.dx = 0 --pl.dx = cdx * pl.facing
					e.capture = capture_lifted
					-- note: x-12 since score formats for 6 places
					add_pl_score(500, pl.x-12, pl.y+4)
					-- todo here: show more extra_scores...
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
					 	e.target.x = e.x 
					 	e.target.y = e.y + 7
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
					 	printh("capturing! "..e.x.." "..e.target.x)
					 	e.dy = -lander_speed*(lander_speed_y_factor/2)
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
						if wxtoc(e.x) < 128 and wxtoc(e.x) > 0 then  -- on screen
							if rnd() < 0.0025 then
							 sfx(7)
								b=add_bullet(e.x, e.y, e)  -- todo pass weak=true
							end
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
						 sfx(7)
							b=add_bullet(e.x, e.y, e)
						end
					end				
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

					-- attack
					-- todo wrap?
					if dx < 128 then
						if rnd() < 0.015 then -- todo higher? var!
						 -- todo?? sfx(7)
							b=add_bullet(e.x, e.y, e, true)  -- track
						end
					end				
				elseif e.k == bomber then
				 if e.y < hudy + rnd(30) or e.y > 120 - rnd(30) then
				 	e.dy *= -1
				 end
					-- lay mine
					-- todo wrap?
					if rnd() < 0.005 then
					 -- todo sfx(?)
						b=add_bullet(e.x, e.y, e)
					end
				elseif e.k == swarmer then
					-- ai
					-- todo overshoot
					if abs(e.x - pl.x) < (rnd(256) - e.lazy) then
					 if e.x < pl.x or rnd()<0.05 then
						 e.dx = swarmer_speed
						else
						 e.dx = -swarmer_speed
					 end
					 
					 if e.y < hudy + rnd(40) and e.y < pl.y and e.dy<0 then
					 	e.dy *= -1
					 elseif e.y > 120 - rnd(40) and e.y > pl.y and e.dy>0 then
					 	e.dy *= -1
					 end
					end

					-- attack
					-- todo wrap?
					if abs(e.x - pl.x) < 128 then
						if rnd() < 0.005 then  -- todo differ from mutant
						 sfx(7)  -- todo differ?
							b=add_bullet(e.x, e.y, e)
						end
					end								
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
				
				-- general bounce to stop y out of bounds
				if e.y < hudy +1 then
				 if e.k == bullet then
			 		del(actors,e)  -- avoid bullet bounce
			 	else
						e.y = hudy +1
						e.dy *= -1
					end
				elseif e.y > 120 then
				 if e.k == bullet then
			 		del(actors,e)  -- avoid bullet bounce
			 	else
						e.y = 120 
						e.dy *= -1
					end
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
 -- todo rename: wave_progression
	local t=time()
	local age = t-wave.t_chunk
	if age > wave_progression then
  wave.t_chunk = t  -- reset
		if humans > 0 then
		 printh("humans at"..t)
			add_humans()
		end
		age = t-wave.t
		if wave.landers > 0 or wave.mutants > 0 or age > wave_old then	 
		 printh("more at"..t)
			add_enemies()
		end
	end
end

function _update60_game_over()
	local t=time()
	local age = t-pl.hit
	local timeout = (age > game_over_delay)
	local some_timeout = (age > 1)  -- make sure we see the message

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
--  reset_player(true)
--
--		-- todo move to reset_game() - include call to reset_player(true) above
--		-- todo stop any sfx - e.g. player dying - or set min key delay > that sfx
--		actors = {}  -- ok?
--		particles = {}
--		lasers = {}
--		iwave = 0
--		humans=0  -- topped up by load_wave
--		load_wave()
  start_game(true)
  
  pl.hit = t
 	_update60 = _update60_wave
 	_draw = _draw_wave
 end
end

function _update60_title()
	local t=time()
	local age = t-pl.hit
	local timeout = (age > title_delay)
	
	if bombing_t == nil then
		add_explosion({x=cx+64,y=48,c=8}, true, particle_speed/2, title_particle_expire)
		--add_explosion({x=cx+64,y=50,c=8}, false, particle_speed, title_particle_expire)
		bombing_t = t
	end

 update_particles()  -- could include special effects
 
 if timeout or btnp(➡️) then
  if pl.score == 0>>16 then
			add_pl_score(450)  -- why? version?
		end
		
  bombing_t = t  -- title explosion done
  particles={}
  pl.hit = t  
 	_update60 = _update60_highscores
 	_draw = _draw_highscores
	elseif btnp(🅾️) or btnp(❎) then
  start_game(true)
  pl.hit = nil  -- start now
 	_update60 = _update60_wave
 	_draw = _draw_wave
 end
end

function _update60_highscores()
	local t=time()
	local age = t-pl.hit
	local timeout = (age > title_delay)

 update_particles()  -- could include special effects
 
 if timeout or btnp(➡️) then
  pl.hit = t

		-- setup instructions - todo move to routine  
		-- todo add add_human routine - though this isn't same/random
		h=make_actor(human,cx+104,120,time())
		h.c=6
		h.h=6
		h.w=2
		h.capture=nil
		h.dropped_y=nil
		--note: avoid (already setup) humans += 1
		
		pl.lives = 0
		pl.bombs = 0
		pl.x = cx+6
		pl.y = hudy+12
		--- end setup

 	_update60 = _update60_instructions
 	_draw = _draw_instructions
	elseif btnp(🅾️) or btnp(❎) then
  start_game(true)
  pl.hit = nil  -- start now
 	_update60 = _update60_wave
 	_draw = _draw_wave
 end
end

function _update60_new_highscore()
	local t=time()
	local age = t-pl.hit
	local timeout = (age > new_highscore_delay)

 update_particles()  -- could include special effects

	-- todo if key: pl.hit = t  -- reset timeout
	if btnp(⬆️) then  -- todo or ⬅️?
		-- todo wrap/limit
		hs_chr = chr(ord(hs_chr)-1)
		pl.hit = t  -- reset timeout
	elseif btnp(⬇️) then  -- todo or ➡️?
		-- todo wrap/limit
		hs_chr = chr(ord(hs_chr)+1)
		pl.hit = t  -- reset timeout
	elseif btnp(❎) then
		hs_name = hs_name .. hs_chr
		pl.hit = t  -- reset timeout
		if #hs_name >= 3 then
			add_highscore(pl.score, hs_name)
	  pl.hit = t 
	 	_update60 = _update60_highscores
	 	_draw = _draw_highscores
		end
	elseif btnp(🅾️) then
		-- todo stop if empty?
		hs_chr = sub(hs_name, #hs_name, #hs_name)
	 hs_name = sub(hs_name, 1, #hs_name-1)
		pl.hit = t  -- reset timeout
 end

 if timeout then
  -- note: too late!
  -- 					 we still add with name of hs_name as-is (default "")
		add_highscore(pl.score, hs_name)
  pl.hit = t
 	_update60 = _update60_highscores
 	_draw = _draw_highscores
 end
end

function _update60_instructions()
 -- note: uses actors and player logic to demo things
	local t=time()
	local age = t-pl.hit
	local timeout = (age > title_delay)

 update_particles()  -- could include special effects

	-- todo remove: (start_game does it)
-- if timeout or btnp(➡️) or (btnp(🅾️) or btnp(❎)) then
--  reset_player(true)  -- note: loses last actual score and demo score will replace it
--
--		-- todo move to reset_game() - include call to reset_player(true) above
--		-- todo stop any sfx - e.g. player dying - or set min key delay > that sfx
-- 	actors={} -- reset - todo move to start_game()?
--		particles = {}
--		lasers = {}
-- end
 -- ...
 if timeout or btnp(➡️) then
  pl.hit = t  
  bombing_t = nil  -- title explosion reset
 	_update60 = _update60_title
 	_draw = _draw_title
	elseif btnp(🅾️) or btnp(❎) then
  start_game(true)
  pl.hit = nil  -- start now
 	_update60 = _update60_wave
 	_draw = _draw_wave
 end
end

function _update60_debug_stop()
 --update_particles()  -- could include special effects
end

-- todo move to tab3?
function start_game(full)
	-- todo old: assumes already reset
--	if pl.score == 450>>16 then
--		add_pl_score(-450)
--	end
 if full then -- todo remove this check!
		reset_player(true)
		-- todo stop any sfx - e.g. player dying - or set min key delay > that sfx
		actors = {}  -- ok?
		lasers = {}
		iwave = 0  -- todo leave out?
		if	debug_test then
			iwave=1
		end
		humans=0  -- topped up by load_wave
		load_wave()
	end

 bombing_t = nil
 particles={}
 add_humans()  -- initial 
 add_enemies() -- initial 
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

function draw_score(v, x,y, extra)
	-- if extra, 1st of 3 digits will be yellow
 x=x or 0
 y=y or 6
 local c=5
 local i=6
 repeat
  local t=v>>>1
  -- todo map to font
  --todo remove: if (y~=6 and i==4) c=10 -- extra_score leading digit
  if (extra and i==4) c=10 -- extra_score leading digit
  print((t%0x0.0005<<17)+(v<<16&1),x+i*4,y,c)
  v=t/5
 	i-=1
 until v==0
end

function add_pl_score(v, x, y)
 assert(v<32767)  
 if x and y then
 	extra_score = {v>>16, wxtoc(x),y, time()}
 end
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
	local c = 1
	if (wave) c=wave.c
	rect(hc,0, hc+hudw,hudy, c)
	line(0,hudy,127,hudy, c)
	line(hc+hdc*4-1,0, hc+hdc*5+1,0, 7)
	pset(hc+hdc*4-1,1, 7)
	pset(hc+hdc*5+1,1, 7)
	line(hc+hdc*4-1,hudy, hc+hdc*5+1,hudy, 7)
	pset(hc+hdc*4-1,hudy-1, 7)
 pset(hc+hdc*5+1,hudy-1, 7)
 
 draw_score(pl.score)
 if extra_score then
  local t = time()
 	local age = t - extra_score[4]
 	if age < extra_score_expire then
		 draw_score(extra_score[1], extra_score[2],extra_score[3], true)
		else
		 extra_score = nil
		end 
 end
 
 for i=1,min(pl.bombs,3) do
 	spr(4,25,-7+i*4)
 end
 for i=1,min(pl.lives,5) do
 	spr(5,(i-1)*5,-4)
 end
end

function draw_player(demo_mode)
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
	
		if debug_kill then
		 local off=((age * laser_size) * laser_rate)
			line(
			 x+(off)*laser[3],
				y-1,
				x+(
				 		off
			 		) * laser[3], 
	  	y-1, 
	  	15
			)					
			--printh(age.." "..x.."("..laser[1]..") "..off*laser[3])	
		end	
	end

	if pl.hit ~= nil and not demo_mode then
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

		if debug_kill then
			rect(x, pl.y+(8-pl.h)/2, x+pl.w, pl.y+8-(pl.h/2), 15)
			if debug_kill and debug_data then
				--local e = debug_rect
				--local ex = wxtoc(e.x)+(8-e.w)/2+e.dx
				--local ey = e.y+(8-e.h)/2+e.dy
				--line(ex, ey,  
				--					wxtoc(pl.x), pl.y+(8-pl.h)/2, 12)						
				--rect(ex, ey,
				--					ex + (e.w+pl.w), ey + (e.h+pl.h), 10)
				line(wxtoc(debug_data[1]), debug_data[2],  
									wxtoc(debug_data[3]), debug_data[4], 12)						
				rect(wxtoc(debug_data[1]), 
									debug_data[2],
									wxtoc(debug_data[1])+debug_data[5], 
									debug_data[2]+debug_data[6], 
									10)
			end
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

			if debug_kill then		 
		 	 rect(x+e.dx+(8-e.w)/2, e.y+e.dy+(8-e.h)/2,
		 	 					x+e.dx+8-(e.w/2), e.y+e.dy+8-(e.h/2), 15) 
	 	end

		end
	end
end

function draw_particles(alt_cycle)
	local t=time()

	local occ, cc_freq = 5, 0.2
	if (alt_cycle) occ, cc_freq = 10, 0.05
	-- palette cycle - as good a place as any
 if t-pt > cc_freq then
  cc = (cc%15) + 1
	 pal(occ, cc) -- todo true?
	 pt = t
 end
 
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
 -- game over
 cls()
 
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

	-- todo 3d text?
	print("game over", 48, hudy+40, 5)
end

function _draw_title()
 -- title
 cls()
 
	draw_particles(true)

	-- never expire! draw_player()  -- needed to expire

	map(0,1, 24,hudy+16, 10,4)

	--print("pico", 56, hudy+31, 10)
	--print("defender", 48, hudy+38, 8)
	
	print("by", 60, hudy+54, 5)
	print("greg gaughan", 40, hudy+60, 5)
end

function _draw_highscores()
 -- highscores
 cls()

	draw_score(pl.score)
	-- todo remove: why extra_score here?
 if extra_score then
  local t = time()
 	local age = t - extra_score[4]
 	if age < extra_score_expire then
		 draw_score(extra_score[1], extra_score[2],extra_score[3], true)
		else
		 extra_score = nil
		end 
 end

 pal(10, 10) 
	draw_particles()

	-- never expire! draw_player()  -- needed to expire

	map(0,1, 24,0, 10,4)
	--print("pico", 56, hudy+1, 10)
	--print("defender", 48, hudy+8, 8)
	print("hall of fame", 40, hudy+24, 5)

	print("todays", 10, hudy+32, 5)
	print("all time", 82, hudy+32, 5)
	print("greatest", 6, hudy+38, 5)
	print("greatest", 82, hudy+38, 5)
	-- todo underlines

	for hst=today,alltime do
	 local co = (hst-1)*76
		for i, hs in pairs(highscores[hst]) do		
 		print(i, 1+co, hudy+40+i*6, 5)
		 if hs[1] ~= nil then
				print(hs[1], 10+co, hudy+40+i*6, 5)
				--print(hs[2], 30+co, hudy+40+i*6, 5)
				draw_score(hs[2], 24+co, hudy+40+i*6)
			end
		end
	end
end

function _draw_new_highscore()
 -- new highscore
 cls()

	draw_score(pl.score)
	-- todo removed if extra_score: why extra_score here?
 
	draw_particles()

	-- never expire! draw_player()  -- needed to expire

	-- todo 3d text?
	print("player one", 56, hudy+1, 2)
	print("you have qualified for", 16, hudy+16, 2)
	print("the defender hall of fame", 16, hudy+24, 2)

	print("select initials with ⬆️/⬇️", 16, hudy+36, 2)

	print("press fire to enter initial", 16, hudy+48, 2)

	-- todo mention bomb to backspace?

	for ci=1,#hs_name do
 	print(sub(hs_name,ci,ci), 54+ci*10, 80, 2)
 end
 local ci = #hs_name+1
	print(hs_chr, 54+ci*10, 80, 2)
	-- underlines
	for ci = #hs_name+2,3 do
 	line(54+ci*10, 88, 54+ci*10+3, 88, 2)
 end

end

function _draw_instructions()
 -- instructions
 cls()

	draw_hud()  -- note: includes extra_score

	-- draw_ground	
	for x = 0,127 do
		i = ((ceil(cx+x))%ww) + 1
		--printh(i)
		pset(x,127 - w[i][1], 4)
	end

	draw_enemies()
	draw_particles()

	draw_player(true)  -- pass demo_mode to aviod dying/reset (because p.hit is overused as a timer here)
 
	-- todo 3d text?
	print("scanner", 52, hudy+4, 5)

	print("1..2..3", 52, hudy+31, 10)
	-- todo: animation steps via timer
end

function _draw_end_wave()
 -- end wave
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
		reset_player()
	 
		iwave += 1
		load_wave()
		-- prime the spawning
		local t=time()
		wave.t_chunk = t - wave_progression + wave_reset  -- reset

		_draw = _draw_wave
	end
end

function _draw_wave()
 local t=time()

 if bombing_t ~= nil then
		local age = t - bombing_t
		if age < bombing_expire then
		 if flr(age * 18) % 2 == 0 then
				cls(7)
			else
				cls(0)
			end
		else
			bombing_t = nil
		end
	else
		cls()
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
	-- todo if hit player - move
 add(actors,a)
	return a
end

function add_bullet(x, y, from, track)
 -- note: also creates mines
 t=time()
	b=make_actor(bullet,x,y)
	local bv = bullet_speed
	if (from and from.k == baiter) bv *= 1.6
	-- todo for some, hang around player?
	local tx,ty = pl.x, pl.y  -- aim at player
	-- todo if bad aimer, add miss (slow bv does this to some extent)
	if track then
	 -- todo also take account of e.dy
	 local proj_speed = bv + from.dx  -- todo remove from.dx?
	 local pldx = cdx * pl.facing
		local ta=pldx*pldx + pl.dy*pl.dy - proj_speed*proj_speed
		local tb=2 * (pldx * (pl.x-b.x) + pl.dy * (pl.y - b.y))
		local tc=(pl.x-b.x)*(pl.x-b.x) + (pl.y-b.y)*(pl.y-b.y)
		local disc=tb*tb - 4 * ta * tc
		if disc >= 0 then
			local t1=(-tb + sqrt(disc)) / (2*ta)
			local t2
			if disc ~= 0 then
				t2=(-tb - sqrt(disc)) / (2*ta)
			else
				t2=t1
			end
			local tt=t1
			if (tt<0 or (t2>tt and t2>0)) tt=t2
			if tt>0 then
				tx = tt * pldx + pl.x
				ty = tt * pl.dy + pl.y
				if (debug)	printh("quadratic solved:"..tt.." ("..pldx..") -> "..tx..","..ty.." instead of "..pl.x..","..pl.y)
			 -- else none +ve (can't fire back in time)
			end	
		-- else no discriminant, forget it - todo perhaps undo fire?
		end
	end
	--b.dx = ((tx - b.x)/128) * bullet_speed
 --b.dy = ((ty - b.y)/128) * bullet_speed
 -- todo why 30!?
	--b.dx = ((tx - b.x)/30) * bv
 --b.dy = ((ty - b.y)/30) * bv
 -- todo here: add miss-factor!
 -- done?-- todo here: add slowdown factor/rate for non-track (landers etc.)
	b.dx = ((tx - b.x)) * bv
 b.dy = ((ty - b.y)) * bv
	b.t = t
	b.w = 1
	b.h = 1
	b.c = 6
	if from and from.k == bomber then
		b.k = mine
		b.dx, b.dy = 0,0	
		b.c = 5
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
  	x+=d[1]*30
  	y+=d[2]*30 
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
	--print("explode "..tostr(explode))
 if explode then
		if not(e.k == bullet or e.k == mine) then
		 add_explosion(e)
	 	if laser then
	 		del(lasers,laser)  -- i.e. allow to hit something else after a bullet
	 	end
	 end
	end
	add_pl_score(e.score)
	--pl.score += e.score >> 16

	del(actors, e)
	printh(e.k.." dead "..e.x)			 	
	
	if e.k == lander then
	 sfx(1)
	 wave.landers_hit += 1
	 
	 if e.target ~= nil then
		 if e.target.capture == capture_lifted then
		 	-- todo drop human
		 	-- todo set drop time / score depending on height/landing
		 	printh("todo drop human!")
		 	e.target.dy = gravity_speed
				e.target.dropped_y = e.y
		 	e.target.capture = nil
		 	sfx(5)
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
	elseif e.k == baiter then
	 wave.baiters_generated -= 1  -- i.e.so max_baiters => max active batiers
		-- todo count baiters_hit - why not
	elseif e.k == bomber then
	 wave.bombers_hit += 1
	elseif e.k == pod then
	 wave.pods_hit += 1
	 -- todo sfx(?)
	 -- spawn swarmers
	 local r = flr(rnd(256))
	 local make = 7
	 if r < 64 then
	  make = 4
	 elseif r < 128 then
	  make = 5
	 elseif r < 172 then
	  make = 6
	 --elseif r < 256 then
	 -- make = 7
	 end
	 if (r == 65) make = 1
	 if (r == 129) make = 2
	 if (r == 173) make = 3
	 make = min(make, max_swarmers - wave.swarmers_generated)
	 for sw = 1,make do
		 local x=e.x+rnd(3)
		 local y=e.y+rnd(6)
			l=make_actor(swarmer,x,y)  -- no time = show immediately
			l.c=9 -- or 8?
			l.dy = swarmer_speed/2
			if (rnd()<0.5) l.dy *= -1
			-- don't go towards player at first: l.dx = swarmer_speed
			-- if (rnd()<0.5) l.dx *= -1
			l.lazy = rnd(64)  -- higher = less likely to chase
			l.h=4
			l.w=5		
			l.score=150	
			-- todo sfx(?)  -- todo: if on screen
		end
		wave.swarmers_generated += make
	elseif e.k == swarmer then
	 wave.swarmers_generated -= 1  -- i.e.so max_swarmers => max active swarmers
		-- todo count swarmers_hit - why not
	elseif e.k == human then
	 -- todo wrap in kill_human routine?
		if e.capture ~= nil then
	  printh("dead human was captured "..e.x.." "..e.capture)
	  -- reset any lander that had this as a target (else picks up a phantom)
	 	for a in all(actors) do
	 		if a.k==lander and a.target==e then
	 			printh("unlinking target after human dead "..a.target.x.." "..a.x)
	 			a.target = nil
	 			-- todo find a new one! (not pl.target)
	 		end
	 	end
 		if pl.target==e then
 			printh("unlinking player target after human dead "..pl.target.x.." "..pl.x)
 			pl.target = nil
 		end
		end
	 humans -= 1
	 -- todo if humans == 0 then null space: convert all landers to mutants
	 -- todo if no more landers/mutants (based on hit counts?) then kill all baiters?
	end
	if is_wave_complete() then
	 pl.hit = time()  -- pause
	 add_pl_score(humans * 100*min(iwave+1,5))
		_draw = _draw_end_wave
	end
end

function reset_player(full)
 if full then
		pl.lives=3
		pl.score=0
		pl.bombs=3
 end
 cdx = 0 -- freeze  
 -- todo reset cx? bombing_t etc.
	pl.x=cx+20
	pl.y=64
	pl.facing=1  -- todo need camera move?
	pl.dx=0 -- todo remove
	pl.dy=0
	pl.thrusting=false
	pl.target = nil
end

function kill_player(e)
 pl.hit = time()
	sfx(3, -2)
	sfx(4)
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
	
	-- todo maybe reset_player() here (if so lose cdx = 0 above)
	
	printh("player killed by "..e.x)
	kill_actor(e, nil, false)  -- no explosion
	if pl.target != nil then
		printh("player was carrying human - also killed "..pl.target.x)
		kill_actor(pl.target, nil)
		-- assume shot - not technically killed by falling from a height?
	end

	if pl.lives < 0 then
	 pl.hit = time()  -- pause
		_draw = _draw_game_over
		_update60 = _update60_game_over
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
		h.dropped_y=nil
	end
end


function active_enemies(include_only)
 -- don't count baiters (and include_only, if given)
 -- don't count bullet,mine,human
 local r = 0
	for e in all(actors) do
	 if (include_only and e.k ~= include_only) then
	   -- ignore
	 else
	  if (not(e.k == baiter or e.k == bullet or e.k == mine or e.k == human)) r+= 1
	 end
 end
 return r
end

function is_wave_complete()
	local r = 0
 -- spawned (except generated baiters)
 r += active_enemies()
	-- plus yet to spawn
	r += wave.landers
	r += wave.bombers
	r += wave.pods
	-- todo? swarmers	
	-- note: baiters not counted towards completion
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
	wave.baiters_generated = 0
	wave.swarmers_generated = 0
	
	if iwave == 0 or ((iwave+1)%5 == 0) then
  -- replenish
		wave.humans_added = 10 - humans
		humans += wave.humans_added
		-- todo: use humans_added to avoid re-adding
		printh("adding humans "..wave.humans_added.."="..humans)
	end

	if	debug_test then
		--wave_old = 1
		--wave_progression=1
		--wave.landers=2 --1
		--wave.bombers=min(1,wave.bombers)
		--wave.pods=min(1,wave.pods)
	end
end

function add_enemies()
 -- todo pass in t?
 -- see reset_enemies for undo
 local make
	if wave.landers > 0 then
	 make = min(wave.landers, 5)
		for e = 1,make do
		 local x=rnd(ww)
		 --local y=rnd(128-hudy)+hudy
		 local y=hudy+2
		 -- todo if hit player - move
			-- note: pass hit time = birthing - wait for implosion to finish  note: also avoids collision detection
			l=make_actor(lander,x,y,time())
			l.dy = lander_speed*lander_speed_y_factor
			l.lazy = rnd(512)  -- higher = less likely to chase
			l.h=5
			l.w=7
			l.score=150	
			-- find a target
			l.target = nil
			if true then --humans > 0 then
				for i,a in pairs(actors) do
					if a.k == human and a.capture==nil then
		 			-- note: e.capture==nil implies not pl.target, i.e. player not carrying
		 			-- todo: though might be funny to have lander steal human from player!
						l.target=a
						l.target.capture = capture_targetted
						printh(l.x.." targetting "..i.." = "..a.x)
						break
					end
				end
			end
			add_explosion(l, true)  -- reverse i.e. spawn
			sfx(2)  -- todo: if on screen
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
			l.dy = mutant_speed*lander_speed_y_factor
			-- todo remove lazy here?
			l.lazy = rnd(512)  -- higher = less likely to chase
			l.h=5
			l.w=7
			l.score=150	
			add_explosion(l, true)  -- reverse i.e. spawn
			sfx(2)  -- todo: if on screen
		end
		wave.mutants -= make
	end
	if wave.bombers > 0 then
	 make = min(wave.bombers, 3) -- ok?
	 local groupx = rnd(ww)
	 local groupdx = 1
		if (rnd() < 0.5) groupdx *= -1
		for e = 1,make do
		 local x=groupx + rnd(ww/20)
		 --local y=rnd(128-hudy)+hudy
		 local y=hudy+2 + rnd(80)
		 -- todo if hit player - move
			-- note: pass hit time = birthing - wait for implosion to finish  note: also avoids collision detection
			l=make_actor(bomber,x,y,time())
			l.c=14
			--l.dy = lander_speed*lander_speed_y_factor
			l.h=4
			l.w=4
			l.dy = bomber_speed
 		if (rnd() < 0.5) l.dy *= -1
			l.dx = groupdx * bomber_speed
			l.score=250	
			add_explosion(l, true)  -- reverse i.e. spawn
			sfx(2)  -- todo: if on screen
		end
		wave.bombers -= make
	end
 if wave.pods > 0 then
	 make = min(wave.pods, 4) -- ok?
		for e = 1,make do
		 local x=rnd(ww)
		 --local y=rnd(128-hudy)+hudy
		 local y=hudy+2+rnd(30)
		 -- todo if hit player - move
			-- note: pass hit time = birthing - wait for implosion to finish  note: also avoids collision detection
			l=make_actor(pod,x,y,time())
			l.c=8
			l.dy=pod_speed
			l.dx=pod_speed/4
			l.h=5
			l.w=7
			l.score=1000	
			add_explosion(l, true)  -- reverse i.e. spawn
			sfx(2)  -- todo: if on screen
		end
		wave.pods -= make
	end
	-- based on wave.t? and/or remaining
 -- baiters, if near end of wave
 if wave.baiters_generated < max_baiters then  -- todo adjust for iwave?
		local t=time()
		local age = t-wave.t
		if age > wave_old*2 or (wave.landers == 0 and wave.bombers == 0 and wave.pods == 0) then
			if age > wave_old*2 or (wave.mutants == 0) then -- todo: include here? active xor this i think?
				local ae = active_enemies(lander) + active_enemies(mutant) -- excludes baiters
				if ae < 5 or age > wave_old*2 then 
					if age > wave_old then  -- todo adjust for iwave?	2,3,4+ need more time?		
					 make = 1 -- remove: 5-ae 
					 if ae < 4 then
							-- prime next one sooner
							wave.t_chunk = t - wave_progression + baiter_next*ae
							printh(ae.." enemies left so priming next baiter respawn for "..wave.t_chunk.." at "..t)
						end			 
						for e = 1,make do
						 local x=rnd(ww)
						 local y=hudy+2
							-- note: pass hit time = birthing - wait for implosion to finish  note: also avoids collision detection
							l=make_actor(baiter,x,y,time())
							l.dy = baiter_speed/3
							l.lazy = -256  -- higher = less likely to chase
							l.h=4
							l.w=7
							l.score=200	
							add_explosion(l, true)  -- reverse i.e. spawn
							sfx(2)  -- todo: if on screen
							printh("new baiter "..l.x)
						end
						-- note: not counted as part of wave: re-generate as needed based on enemies left/wave.t
						wave.baiters_generated += make
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
	t = time()
	for e in all(actors) do
		-- todo check not just hit?
		if e.k == bullet then
			--printh(e.k.." removed "..e.x)			 	
		elseif e.k == mine then
			--printh(e.k.." removed "..e.x)			 	
		elseif e.k == lander then
			--printh(e.k.." undead "..e.x)			 	
			wave.landers	+= 1
		elseif e.k == mutant then
			--printh(e.k.." undead "..e.x)			 	
			--todo old: note: no need: already added on conversion: 
			wave.mutants	+= 1
		elseif e.k == bomber then
			--printh(e.k.." undead "..e.x)			 	
			wave.bombers	+= 1
		elseif e.k == pod then
			--printh(e.k.." undead "..e.x)			 	
			wave.pods	+= 1
		elseif e.k == human then
			--printh(e.k.." removed "..e.x)			 		
			-- accounted for by humans var
		elseif e.k == baiter then
			--printh(e.k.." removed "..e.x)			 		
			-- not counted: re-generate as needed
		elseif e.k == swarmer then
			--printh(e.k.." removed "..e.x)			 		
			-- not counted: re-generate as needed
		else
			assert(false, "unknown e.k:"..e.k)		
		end
		del(actors, e)  -- note: we don't retain the positions on respawn!
	end
	wave.baiters_generated = 0
	wave.swarmers_generated = 0
	-- prime the respawning
	wave.t_chunk = t - wave_progression + wave_reset  -- reset
end

function load_highscores()
	if cart_exists then
	 -- note: 8 slots hardcoded here
		-- note: bytes 0+1 for future use
		for hs=1,8 do
			--local name_bytes = dget(hs*2)
			local name = nil  -- i.e. stored as 0
			-- endian issue?
--			if name_bytes ~= 0 then
--				printh("24:"..((name_bytes>>>24) & 0xff))
--				printh("16:"..((name_bytes>>>16) & 0xff))
--				printh(" 8:"..((name_bytes>>>8) & 0xff))
--				name = "" .. chr((name_bytes>>>24) & 0xff)
--				name = name..chr((name_bytes>>>16) & 0xff)
--				name = name..chr((name_bytes>>>8) & 0xff)
--				-- note: ignore (name_bytes>>>0) & 0xff
--			end
   -- todo @ instead of peek
			local c1=peek(0x5e00 + (hs*2)*4+0) 
   local c2=peek(0x5e00 + (hs*2)*4+1)
			local c3=peek(0x5e00 + (hs*2)*4+2)
			--local c4=peek(0x5e00 + (hs*2)*4+3)
			-- todo assert c4==0
			if c1 ~= 0 or c2 ~= 0 or c3 ~= 0 then
				name = chr(c1)..chr(c2)..chr(c3)
				printh("!"..name.." "..c1..c2..c3)
			-- else ?assert score==0
			end
			local score = dget(hs*2+1)
			if score ~= 0 then
				add_highscore(score, name, false)
			-- else empty cart (first run) or nothing saved here yet
			end
		end 
	else
 	printh("skipped dget: not cart_exists")
 	-- todo remove/debug?
	 -- note: needs to be >>16 if > 32k
	 -- todo: add via add_highscore to ensure they're kept in order!
	 highscores[alltime][1]={"gjg", 21270>>16}
	 -- load highscores[alltime] from cart data
	end
  
	if debug then
	 highscores[today][1]={"gjg", 21270>>16}
	 highscores[today][2]={"g2g", 11270>>16}
	 highscores[today][3]={"g3g", 1270>>16}
	 highscores[today][4]={"g4g", 270>>16}
	end
end

function add_highscore(score, name, new)
	-- assumes caller already knows we have a highscore (e.g. checked against [8])
	-- pass new=false if loading from cdata, i.e. don't try to store = cycle!
	if (new == nil) new = true
 -- find position 
 for hst=today,alltime do
 	-- todo short-circuit if not possibly in alltime, based on today pos
	 local pos = #highscores[hst]  -- i.e. 8
	 while pos>0 and score >	highscores[hst][pos][2] do
		 pos -= 1
	 end
	 if pos ~= #highscores[hst] then
		 if pos >= 0  then
		 	-- push others down
		 	for hs=#highscores[hst], pos+2, -1 do
			 	highscores[hst][hs] = highscores[hst][hs-1]  -- copies name+score
		 	end
		 	-- insert
 		 -- todo >>16 here? or caller?
		 	highscores[hst][pos+1] = {name, score}
		 	
		 	if hst == alltime and new then
					printh("writing alltime highscore to cart "..name..":"..score.." at "..pos+1)
					if true then -- todo remove: cart_exists then
					 -- note: 8 slots hardcoded here
						-- note: bytes 0+1 for future use
						for hs=1,8 do
						 local hs_name = highscores[hst][hs][1]
						 local name_bytes = 0  -- i.e. nil = not set
						 -- endian issue?
--						 if hs_name ~= nil then
--							 name_bytes = (ord(sub(hs_name,1,1)) << 24) |
--																					(ord(sub(hs_name,2,2)) << 16) |
--																					(ord(sub(hs_name,3,3)) << 8) |
--																					(ord(chr(0)) << 0) 
--								printh("!"..hs_name.." "..name_bytes)
--							end
--							dset(hs*2, name_bytes)
						 if hs_name ~= nil then
							 poke(0x5e00 + (hs*2)*4+0, ord(sub(hs_name,1,1))) 
        poke(0x5e00 + (hs*2)*4+1, ord(sub(hs_name,2,2)))
								poke(0x5e00 + (hs*2)*4+2, ord(sub(hs_name,3,3)))
								poke(0x5e00 + (hs*2)*4+3, ord(chr(0)))
								printh("!"..hs_name.." "..name_bytes)
							end
							dset(hs*2+1, highscores[hst][hs][2])
						end 			 
					else
						printh("failed dset: not cart_exists")
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
007007000d000000eee6666b00000000000700000d0000000000000000004000000400000b00b00b0b00b00b0b00b00b00000000000000000000000000000000
00000000dddd1900000000000000000000000000eed5000000000000000040000004000000000000000000000000000000000000000000000000000000000000
000000000e73dd730000000000000000000000000edd300000000000000000000000000000000000000000000000000000000000000000000000000000000000
50505005550500550055050505055055505550505055555057755555555555550000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550000000000055b00000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550000000000b55eb0000000000000000000000000000000000000000000000000
555555555555555555555555555555555555555555555555555555555555555500077000000e2e00000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550007700000b040b0000000000000000000000000000000000000000000000000
5555555555555555555555555555555555555555555555555555555555555555000000000b00400b000000000000000000000000000000000000000000000000
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
00000908000007e80000097000000778000000000000000000000000000000000000000000555e00000000000000000000000000000000000000000000000000
0000077e0000087000000eee000009000000000000000000000000000000000000000000005a5e00000000000000000000000000000000000000000000000000
00000708000000000000000000000000000000000000000000000000000000000000000000555000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000050a050000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000e5e00000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000005e5e5e5000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000e5e00000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000050a050000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000b0b00000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000b000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000b0b00000000000000000000000000000000000000000000000000
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
000000000000000000000000000000000aa000a00aaa000aa0000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000a8aa0aa0aa8aa0aaaa000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000a88aa0a80aa8aa0aa8aa00000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000a88aa8aa8aaa0880aa88aa0000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000aaaaa88aa8aaa0880aaa88aa000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000aaa8888aaa8aaa00008aa88aa000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000aaa88888aa88aaa00aa8aaa88aa00000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000aaa88000aaa80aaaaaaa88aaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000aaa80000aaa808aaaaa8088aaaa800000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000888800008888088888880088888800000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000888000008880008888800008888000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000aaaaa00aaaaaa0aaaaaa0aaaaaa0aa0000a00aaaaaa00aaaaa0aaaaa0000000000000000000000000000000000000000000000000000000000000
0000000000aaaaaa00aaaaa80aaaaa00aaaaaa0aaa000aa8aaaaaaa8aaaaaa8aaaaa000000000000000000000000000000000000000000000000000000000000
000000000aaa88aa0aa88888aa88880aa888880aaaa00aa8aa888aa8aa88888aa88aa00000000000000000000000000000000000000000000000000000000000
00000000aaa88aa8aa888888aa88880aa888880aaaaa0aa8aa8888aa8aa88888aa88aa0000000000000000000000000000000000000000000000000000000000
0000000aaa888aa8aaaaaa8aaaaaa0aaaaaa000aa8aaaaa88aa888aa8aaaaa88aaaaaa0000000000000000000000000000000000000000000000000000000000
000000aaa888aa8aaaaaa88aaaaa00aaaaaa000aa88aaaaa8aa8888aa8aaaaa88aaaaaa000000000000000000000000000000000000000000000000000000000
00000aaa8888aa8aa88888aaa8880aaa8888000aa888aaaa8aa8888aa8aa88888aa8aaaa00000000000000000000000000000000000000000000000000000000
0000aaa8888aa8aa888888aa88880aaa8888000aa0888aaa8aaa888aaa8aa88888aa88aaa0000000000000000000000000000000000000000000000000000000
000aaaaaaaaaa8aaaaaaa8aa8880aaaaaaaaaa0aa0088aaa88aaaaaaaa8aaaaaaa8aa88aaa000000000000000000000000000000000000000000000000000000
00aaaaaaaaaa8aaaaaaa8aaa8000aaaaaaaaaa0aa00888aaa8aaaaaaaa88aaaaaaa8aa88aaa00000000000000000000000000000000000000000000000000000
0aaaaaaaaaa88aaaaaaa8aa88000aaaaaaaaaa0aa00088aaa8aaaaaaa888aaaaaaa8aaa88aaa0000000000000000000000000000000000000000000000000000
08888888888888888888888800008888888888088000888888888888888888888888888888880000000000000000000000000000000000000000000000000000
08888888888888888888088800008888888888088000088880888888880888888880888088880000000000000000000000000000000000000000000000000000
08888888888088888888088800008888888888088000008880888888800088888880888008880000000000000000000000000000000000000000000000000000
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
0000000000000000000202020000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
