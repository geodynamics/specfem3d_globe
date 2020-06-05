module BOAST
  def BOAST::compute_element_gravity( type, n_gll3 = 125)
    if type == :inner_core then
      function_name = "compute_element_ic_gravity"
    elsif type == :crust_mantle then
      function_name = "compute_element_cm_gravity"
    else
      raise "Unsupported type : #{type}!"
    end
    ngll3 = Int("NGLL3", :const => n_gll3)
    v = []
    v.push tx                      = Int( "tx",                :dir => :in)
    v.push iglob                   = Int( "iglob",             :dir => :in)
    #v.push working_element         = Int( "working_element",   :dir => :in)
    #v.push d_ibool                 = Int("d_ibool",                  :dir => :in, :dim => [Dim()] )
    v.push d_rstore                = Real("d_rstore",                :dir => :in, :restrict => true, :dim => [Dim(3), Dim()] )
    v.push d_minus_gravity_table   = Real("d_minus_gravity_table",   :dir => :in, :restrict => true, :dim => [Dim()] )
    v.push d_minus_deriv_gravity_table = Real("d_minus_deriv_gravity_table", :dir => :in, :restrict => true, :dim => [Dim()] )
    v.push d_density_table         = Real("d_density_table",         :dir => :in, :restrict => true, :dim => [Dim()] )
    v.push wgll_cube               = Real("wgll_cube",               :dir => :in, :restrict => true, :dim => [Dim()] )
    v.push jacobianl               = Real("jacobianl", :dir => :in)
    v.push *s_dummy_loc = ["x", "y", "z"].collect { |a|
                                     Real("s_dummy#{a}_loc", :dir => :in, :dim => [Dim(ngll3)], :local => true )
    }
    sigma = ["x", "y", "z"].collect { |a1|
        ["x", "y", "z"].collect { |a2|
                                     Real("sigma_#{a1}#{a2}", :dir => :inout, :dim => [Dim()], :private => true )
        }
    }
    v.push sigma[0][0], sigma[1][1], sigma[2][2],\
           sigma[0][1], sigma[1][0], sigma[0][2],\
           sigma[2][0], sigma[1][2], sigma[2][1]
    v.push *rho_s_H = [1,2,3].collect {|n|
                                     Real("rho_s_H#{n}", :dir => :inout, :dim => [Dim()], :private => true )
    }
    v.push r_earth_km               = Real("R_EARTH_KM", :dir => :in)

    p = Procedure(function_name, v, :local => true) {
      decl radius = Real("radius"), theta = Real("theta"), phi = Real("phi")
      decl cos_theta = Real("cos_theta"), sin_theta = Real("sin_theta"), cos_phi = Real("cos_phi"), sin_phi = Real("sin_phi")
      decl cos_theta_sq = Real("cos_theta_sq"), sin_theta_sq = Real("sin_theta_sq"), cos_phi_sq = Real("cos_phi_sq"), sin_phi_sq = Real("sin_phi_sq")
      decl minus_g = Real("minus_g"), minus_dg = Real("minus_dg")
      decl rho = Real("rho")
      decl *gl = [ Real("gxl"), Real("gyl"), Real("gzl") ]
      decl minus_g_over_radius = Real("minus_g_over_radius"), minus_dg_plus_g_over_radius = Real("minus_dg_plus_g_over_radius")
      decl hxxl = Real("Hxxl"), hyyl = Real("Hyyl"), hzzl = Real("Hzzl"), hxyl = Real("Hxyl"), hxzl = Real("Hxzl"), hyzl = Real("Hyzl")
      decl *s_l = [ Real("sx_l"), Real("sy_l"), Real("sz_l") ]
      decl factor = Real("factor")
      decl int_radius = Int("int_radius")
      decl nrad_gravity = Int("nrad_gravity")
      comment()

      print radius === d_rstore[0,iglob]
      print theta === d_rstore[1,iglob]
      print phi === d_rstore[2,iglob]
      comment()

      print If(radius < ( 100.0 / (r_earth_km*1000.0))) {
        print radius ===  100.0 / (r_earth_km*1000.0)
      }
      comment()

      if (get_lang == CL) then
        print sin_theta === sincos(theta, cos_theta.address)
        print sin_phi   === sincos(phi,   cos_phi.address)
      else
        if (get_default_real_size == 4) then
          print sincosf(theta, sin_theta.address, cos_theta.address)
          print sincosf(phi,   sin_phi.address,   cos_phi.address)
        else
          print cos_theta === cos(theta)
          print sin_theta === sin(theta)
          print cos_phi   === cos(phi)
          print sin_phi   === sin(phi)
        end
      end
      comment()

      # daniel todo: note that the CPU version removes the ellipticity factor from r
      #              this requires the ellpticity spline which are not available yet on GPU.
      #              we therefore omit this correction for now...
      #
      #r_table = radius
      #if (ELLIPTICITY) call revert_ellipticity_rtheta(r_table,theta,nspl,rspl,ellipicity_spline,ellipicity_spline2)

      # old: int_radius = nint(10.d0 * radius * R_PLANET_KM)
      #print int_radius === rint(radius * r_earth_km * 10.0 ) - 1
      #print If(int_radius < 0 ) { print int_radius === 0 }

      # new: int_radius = dble(int_radius) / dble(NRAD_GRAVITY) * range_max
      #print int_radius === rint( r_table / range_max * dble(NRAD_GRAVITY) ) - 1
      # daniel todo:
      #   NRAD_GRAVITY set in constants.h: NRAD_GRAVITY = 70000 - this could be made an argument or constant
      #   range_max = (R_PLANET + dble(TOPO_MAXIMUM))/R_PLANET with TOPO_MAXIMUM = 9000.0 (m, Earth)
      # we simplify: r_table / range_max * dble(NRAD_GRAVITY)  to radius / ((r_earth_km + 9.0)/r_earth_km) * NRAD_GRAVITY
      print nrad_gravity === 70000
      print int_radius === rint( radius / ((r_earth_km + 9.0)/r_earth_km) * nrad_gravity) - 1
      # limits range
      print If(int_radius < 0){ print int_radius === 0 }
      print If(int_radius > nrad_gravity-1){ print int_radius === nrad_gravity-1 }
      comment()

      print minus_g  === d_minus_gravity_table[int_radius]
      print minus_dg === d_minus_deriv_gravity_table[int_radius]
      print rho      === d_density_table[int_radius]
      comment()

      #daniel todo: new with pre-calculated arrays
      # Cartesian components of the gravitational acceleration
      #gxl = gravity_pre_store(1,iglob) ! minus_g*sin_theta*cos_phi * rho
      #gyl = gravity_pre_store(2,iglob) ! minus_g*sin_theta*sin_phi * rho
      #gzl = gravity_pre_store(3,iglob) ! minus_g*cos_theta * rho

      print gl[0] === minus_g*sin_theta*cos_phi
      print gl[1] === minus_g*sin_theta*sin_phi
      print gl[2] === minus_g*cos_theta

      print minus_g_over_radius === minus_g / radius
      print minus_dg_plus_g_over_radius === minus_dg - minus_g_over_radius

      print cos_theta_sq === cos_theta*cos_theta
      print sin_theta_sq === sin_theta*sin_theta
      print cos_phi_sq   === cos_phi*cos_phi
      print sin_phi_sq   === sin_phi*sin_phi
      comment()

      #daniel todo: new with pre-calculated arrays
      #Hxxl = gravity_H(1,iglob) ! minus_g_over_radius*(cos_phi_sq*cos_theta_sq + sin_phi_sq) + cos_phi_sq*minus_dg*sin_theta_sq * rho
      #Hyyl = gravity_H(2,iglob) ! minus_g_over_radius*(cos_phi_sq + cos_theta_sq*sin_phi_sq) + minus_dg*sin_phi_sq*sin_theta_sq * rho
      #Hzzl = gravity_H(3,iglob) ! cos_theta_sq*minus_dg + minus_g_over_radius*sin_theta_sq * rho
      #Hxyl = gravity_H(4,iglob) ! cos_phi*minus_dg_plus_g_over_radius*sin_phi*sin_theta_sq * rho
      #Hxzl = gravity_H(5,iglob) ! cos_phi*cos_theta*minus_dg_plus_g_over_radius*sin_theta * rho
      #Hyzl = gravity_H(6,iglob) ! cos_theta*minus_dg_plus_g_over_radius*sin_phi*sin_theta * rho


      print hxxl === minus_g_over_radius*(cos_phi_sq*cos_theta_sq + sin_phi_sq) + cos_phi_sq*minus_dg*sin_theta_sq
      print hyyl === minus_g_over_radius*(cos_phi_sq + cos_theta_sq*sin_phi_sq) + minus_dg*sin_phi_sq*sin_theta_sq
      print hzzl === cos_theta_sq*minus_dg + minus_g_over_radius*sin_theta_sq
      print hxyl === cos_phi*minus_dg_plus_g_over_radius*sin_phi*sin_theta_sq
      print hxzl === cos_phi*cos_theta*minus_dg_plus_g_over_radius*sin_theta
      print hyzl === cos_theta*minus_dg_plus_g_over_radius*sin_phi*sin_theta
      comment()

      (0..2).each { |indx|
        print s_l[indx] === rho * s_dummy_loc[indx][tx]
      }
      comment()

      print sigma[0][0].dereference === sigma[0][0].dereference + s_l[1]*gl[1] + s_l[2]*gl[2];
      print sigma[1][1].dereference === sigma[1][1].dereference + s_l[0]*gl[0] + s_l[2]*gl[2];
      print sigma[2][2].dereference === sigma[2][2].dereference + s_l[0]*gl[0] + s_l[1]*gl[1];

      print sigma[0][1].dereference === sigma[0][1].dereference - s_l[0] * gl[1];
      print sigma[1][0].dereference === sigma[1][0].dereference - s_l[1] * gl[0];

      print sigma[0][2].dereference === sigma[0][2].dereference - s_l[0] * gl[2];
      print sigma[2][0].dereference === sigma[2][0].dereference - s_l[2] * gl[0];

      print sigma[1][2].dereference === sigma[1][2].dereference - s_l[1] * gl[2];
      print sigma[2][1].dereference === sigma[2][1].dereference - s_l[2] * gl[1];
      comment()

      # precompute vector
      #factor = jacobianl(INDEX_IJK) * wgll_cube(INDEX_IJK)
      #rho_s_H(1,INDEX_IJK) = factor * (sx_l * Hxxl + sy_l * Hxyl + sz_l * Hxzl)
      #rho_s_H(2,INDEX_IJK) = factor * (sx_l * Hxyl + sy_l * Hyyl + sz_l * Hyzl)
      #rho_s_H(3,INDEX_IJK) = factor * (sx_l * Hxzl + sy_l * Hyzl + sz_l * Hzzl)

      print factor === jacobianl * wgll_cube[tx]
      print rho_s_H[0][0] === factor * (s_l[0]*hxxl + s_l[1]*hxyl + s_l[2]*hxzl)
      print rho_s_H[1][0] === factor * (s_l[0]*hxyl + s_l[1]*hyyl + s_l[2]*hyzl)
      print rho_s_H[2][0] === factor * (s_l[0]*hxzl + s_l[1]*hyzl + s_l[2]*hzzl)
    }
    return p
  end
end
