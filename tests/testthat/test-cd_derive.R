test_that("cd_derive_vpd computes correct VPD from known values", {
  # 20°C temp, 10°C dewpoint in Kelvin
  temp <- terra::rast(nrows = 2, ncols = 2, vals = rep(293.15, 4))
  dewp <- terra::rast(nrows = 2, ncols = 2, vals = rep(283.15, 4))

  vpd <- cd:::cd_derive_vpd(temp, dewp)
  vals <- terra::values(vpd)

  # Tetens: es(20) = 6.1078 * exp(17.27*20/237.3+20) = 23.37 hPa
  # Tetens: ea(10) = 6.1078 * exp(17.27*10/237.3+10) = 12.27 hPa
  # VPD = 23.37 - 12.27 = 11.10 hPa
  expect_true(all(vals > 10 & vals < 12))
})

test_that("cd_derive_vpd is zero when temp equals dewpoint", {
  temp <- terra::rast(nrows = 2, ncols = 2, vals = rep(288.15, 4))
  dewp <- terra::rast(nrows = 2, ncols = 2, vals = rep(288.15, 4))

  vpd <- cd:::cd_derive_vpd(temp, dewp)
  vals <- terra::values(vpd)

  expect_true(all(abs(vals) < 0.001))
})

test_that("cd_derive_rh is 100% when temp equals dewpoint", {
  temp <- terra::rast(nrows = 2, ncols = 2, vals = rep(288.15, 4))
  dewp <- terra::rast(nrows = 2, ncols = 2, vals = rep(288.15, 4))

  rh <- cd:::cd_derive_rh(temp, dewp)
  vals <- terra::values(rh)

  expect_true(all(abs(vals - 100) < 0.01))
})

test_that("cd_derive_rh is between 0 and 100 for valid inputs", {
  temp <- terra::rast(nrows = 2, ncols = 2, vals = rep(293.15, 4))
  dewp <- terra::rast(nrows = 2, ncols = 2, vals = rep(283.15, 4))

  rh <- cd:::cd_derive_rh(temp, dewp)
  vals <- terra::values(rh)

  expect_true(all(vals > 0 & vals < 100))
})

test_that("cd_derive_soil computes mean of 4 layers", {
  layers <- c(
    terra::rast(nrows = 2, ncols = 2, vals = rep(0.1, 4)),
    terra::rast(nrows = 2, ncols = 2, vals = rep(0.2, 4)),
    terra::rast(nrows = 2, ncols = 2, vals = rep(0.3, 4)),
    terra::rast(nrows = 2, ncols = 2, vals = rep(0.4, 4))
  )

  sm <- cd:::cd_derive_soil(layers)
  vals <- terra::values(sm)

  expect_equal(vals[1], 0.25)
})

test_that("cd_derive is a function", {
  expect_true(is.function(cd_derive))
})
