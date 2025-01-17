# Hey Emacs, this is a -*- makefile -*-
#
# Copyright (C) 2008 Antoine Drouin
#
# This file is part of paparazzi.
#tin
# paparazzi is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# paparazzi is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with paparazzi; see the file COPYING.  If not, write to
# the Free Software Foundation, 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.
#
#

######################################################################
##
## COMMON FIXEDWING ALL TARGETS (SIM + AP + FBW ...)
##


#
# Board config + Include paths
#

$(TARGET).CFLAGS 	+= -DBOARD_CONFIG=$(BOARD_CFG)
$(TARGET).CFLAGS 	+= -DPERIPHERALS_AUTO_INIT
$(TARGET).CFLAGS 	+= $(FIXEDWING_INC)

$(TARGET).srcs 	+= mcu.c
$(TARGET).srcs 	+= $(SRC_ARCH)/mcu_arch.c

#
# Common Options
#

ifeq ($(OPTIONS), minimal)
else
  $(TARGET).CFLAGS 	+= -DWIND_INFO
endif

$(TARGET).CFLAGS 	+= -DTRAFFIC_INFO

#
# frequencies
#
PERIODIC_FREQUENCY ?= 60
$(TARGET).CFLAGS += -DPERIODIC_FREQUENCY=$(PERIODIC_FREQUENCY)

ifdef AHRS_PROPAGATE_FREQUENCY
$(TARGET).CFLAGS += -DAHRS_PROPAGATE_FREQUENCY=$(AHRS_PROPAGATE_FREQUENCY)
endif

ifdef AHRS_CORRECT_FREQUENCY
$(TARGET).CFLAGS += -DAHRS_CORRECT_FREQUENCY=$(AHRS_CORRECT_FREQUENCY)
endif

ifdef AHRS_MAG_CORRECT_FREQUENCY
$(TARGET).CFLAGS += -DAHRS_MAG_CORRECT_FREQUENCY=$(AHRS_MAG_CORRECT_FREQUENCY)
endif

#
# Sys-time
#
$(TARGET).srcs   += mcu_periph/sys_time.c $(SRC_ARCH)/mcu_periph/sys_time_arch.c
ifeq ($(ARCH), linux)
# seems that we need to link against librt for glibc < 2.17
$(TARGET).LDFLAGS += -lrt
endif

#
# InterMCU & Commands
#
$(TARGET).CFLAGS 	+= -DINTER_MCU
$(TARGET).srcs 		+= $(SRC_FIXEDWING)/inter_mcu.c

#
# Math functions
#
ifneq ($(TARGET),fbw)
$(TARGET).srcs += math/pprz_geodetic_int.c math/pprz_geodetic_float.c math/pprz_geodetic_double.c math/pprz_trig_int.c math/pprz_orientation_conversion.c math/pprz_algebra_int.c math/pprz_algebra_float.c math/pprz_algebra_double.c
endif

#
# I2C
#
ifneq ($(TARGET),fbw)
$(TARGET).srcs += mcu_periph/i2c.c
$(TARGET).srcs += $(SRC_ARCH)/mcu_periph/i2c_arch.c
endif

######################################################################
##
## COMMON FOR ALL NON-SIMULATION TARGETS
##

#
# Interrupt Vectors
#
ifeq ($(ARCH), lpc21)
  ns_srcs 		+= $(SRC_ARCH)/armVIC.c
endif

ifeq ($(ARCH), stm32)
  ns_srcs       += $(SRC_ARCH)/mcu_periph/gpio_arch.c
endif


#
# Main
#
ifeq ($(RTOS), chibios-libopencm3)
 ns_srcs += $(SRC_FIRMWARE)/main_chibios_libopencm3.c
 ns_srcs += $(SRC_FIRMWARE)/chibios-libopencm3/chibios_init.c
else
 ns_srcs += $(SRC_FIRMWARE)/main.c
endif

#
# LEDs
#
SYS_TIME_LED ?= none
ns_CFLAGS 		+= -DUSE_LED
ifneq ($(SYS_TIME_LED),none)
  ns_CFLAGS 	+= -DSYS_TIME_LED=$(SYS_TIME_LED)
endif
ifneq ($(ARCH), lpc21)
  ns_srcs 	+= $(SRC_ARCH)/led_hw.c
endif


#
# UARTS
#
ns_srcs 		+= mcu_periph/uart.c
ns_srcs 		+= $(SRC_ARCH)/mcu_periph/uart_arch.c


#
# ANALOG
#
ns_CFLAGS 		+= -DUSE_ADC
ns_srcs 			+= $(SRC_ARCH)/mcu_periph/adc_arch.c

######################################################################
##
## FLY BY WIRE THREAD SPECIFIC
##

fbw_CFLAGS		+= -DFBW
fbw_srcs 		+= $(SRC_FIRMWARE)/main_fbw.c
fbw_srcs 		+= subsystems/electrical.c
fbw_srcs 		+= subsystems/commands.c
fbw_srcs 		+= subsystems/actuators.c

######################################################################
##
## AUTOPILOT THREAD SPECIFIC
##

ap_CFLAGS 		+= -DAP
ap_srcs 		+= $(SRC_FIRMWARE)/main_ap.c
ap_srcs 		+= $(SRC_FIRMWARE)/autopilot.c
ap_srcs 		+= state.c
ap_srcs 		+= subsystems/settings.c
ap_srcs 		+= $(SRC_ARCH)/subsystems/settings_arch.c


# BARO
include $(CFG_SHARED)/baro_board.makefile


######################################################################
##
## SIMULATOR THREAD SPECIFIC
##

UNAME = $(shell uname -s)
ifeq ("$(UNAME)","Darwin")
  sim.CFLAGS += $(shell if test -d /opt/paparazzi/include; then echo "-I/opt/paparazzi/include"; elif test -d /opt/local/include; then echo "-I/opt/local/include"; fi)
endif

sim.CFLAGS  	+= $(CPPFLAGS)
sim.CFLAGS 		+= $(fbw_CFLAGS) $(ap_CFLAGS)
sim.srcs 		+= $(fbw_srcs) $(ap_srcs)

sim.CFLAGS 		+= -DSITL
sim.srcs 		+= $(SRC_ARCH)/sim_ap.c

sim.CFLAGS 		+= -DDOWNLINK -DPERIODIC_TELEMETRY -DDOWNLINK_TRANSPORT=ivy_tp -DDOWNLINK_DEVICE=ivy_tp
sim.srcs 		+= subsystems/datalink/downlink.c $(SRC_FIRMWARE)/datalink.c $(PAPARAZZI_HOME)/var/share/pprzlink/src/ivy_transport.c subsystems/datalink/telemetry.c $(SRC_FIRMWARE)/ap_downlink.c $(SRC_FIRMWARE)/fbw_downlink.c

sim.srcs 		+= $(SRC_ARCH)/sim_gps.c $(SRC_ARCH)/sim_adc_generic.c

# hack: always compile some of the sim functions, so ocaml sim does not complain about no-existing functions
sim.srcs        += $(SRC_ARCH)/sim_ahrs.c $(SRC_ARCH)/sim_ir.c

######################################################################
##
## Final Target Allocations
##

#
# SINGLE MCU / DUAL MCU
#

ifeq ($(BOARD),classix)
  include $(CFG_FIXEDWING)/intermcu_spi.makefile
else
  # Single MCU's run both
  ifeq ($(SEPARATE_FBW),)
    ap.CFLAGS 		+= $(fbw_CFLAGS)
    ap.srcs 		+= $(fbw_srcs)
  endif
endif

#
# No-Sim parameters
#

fbw.CFLAGS 		+= $(fbw_CFLAGS) $(ns_CFLAGS)
fbw.srcs 		+= $(fbw_srcs) $(ns_srcs)

ap.CFLAGS 		+= $(ap_CFLAGS) $(ns_CFLAGS)
ap.srcs 		+= $(ap_srcs) $(ns_srcs)
