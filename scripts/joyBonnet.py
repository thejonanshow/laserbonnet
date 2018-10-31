#!/usr/bin/python

# Somewhat minimal Adafruit Joy Bonnet handler.  Runs in background,
# translates inputs from buttons and ADC joystick to virtual USB keyboard
# events.
# Prerequisites:
# sudo apt-get install python-pip python-smbus python-dev
# sudo pip install evdev
# Be sure to enable I2C via raspi-config.  Also, udev rules will need to
# be set up per retrogame directions.
# Credit to Pimoroni for Picade HAT scripts as starting point.

import time
import signal
import os
import sys
import socket
import atexit
from datetime import datetime
from subprocess import call
import thread
import yaml

try:
    import httplib
except:
    import http.client as httplib
try:
    import RPi.GPIO as gpio
except ImportError:
    exit("This library requires the RPi.GPIO module\nInstall with: sudo pip install RPi.GPIO")

try:
     from smbus import SMBus
except ImportError:
    exit("This library requires the smbus module\nInstall with: sudo pip install smbus")

config_path = os.path.join(os.path.dirname(__file__), "..", "config", "production.yaml")
with open(config_path) as yaml_stream:
    config = yaml.safe_load(yaml_stream)

DEBUG = False
BOUNCE_TIME = 0.01 # Debounce time in seconds

BUTTON_A = 12
BUTTON_B = 6
BUTTON_X = 16
BUTTON_Y = 13
SELECT   = 20
START    = 26
PLAYER1  = 23
PLAYER2  = 22
UP       = 1000
DOWN     = 1001
LEFT     = 1002
RIGHT    = 1003
BUTTONS  = [BUTTON_A, BUTTON_B, BUTTON_X, BUTTON_Y, SELECT, START, PLAYER1, PLAYER2]

ANALOG_THRESH_NEG = -600
ANALOG_THRESH_POS = 600
analog_states = [False, False, False, False]  # up down left right
button_states = {
        BUTTON_A: False,
        BUTTON_B: False,
        BUTTON_X: False,
        BUTTON_Y: False,
        SELECT:   False,
        START:    False,
        PLAYER1:  False,
        PLAYER2:  False
}

KEY_PRESS = {
        BUTTON_A: 'a',
        BUTTON_B: 'b',
        BUTTON_X: 'x',
        BUTTON_Y: 'y',
        SELECT:   't',
        START:    's',
        PLAYER1:  'o',
        PLAYER2:  'w',
        UP:       'u',
        DOWN:     'd',
        LEFT:     'l',
        RIGHT:    'r',
}

KEY_RELEASE = {
        BUTTON_A: '1',
        BUTTON_B: '2',
        BUTTON_X: '3',
        BUTTON_Y: '4',
        SELECT:   '5',
        START:    '6',
        PLAYER1:  '7',
        PLAYER2:  '8',
        UP:       '9',
        DOWN:     '0',
        LEFT:     '-',
        RIGHT:    '=',
}


###################################### ADS1015 microdriver #################################
# Register and other configuration values:
ADS1x15_DEFAULT_ADDRESS        = 0x48
ADS1x15_POINTER_CONVERSION     = 0x00
ADS1x15_POINTER_CONFIG         = 0x01

ADS1015_REG_CONFIG_CQUE_NONE    = 0x0003 # Disable the comparator and put ALERT/RDY in high state (default)
ADS1015_REG_CONFIG_CLAT_NONLAT  = 0x0000 # Non-latching comparator (default)
ADS1015_REG_CONFIG_CPOL_ACTVLOW = 0x0000 # ALERT/RDY pin is low when active (default)
ADS1015_REG_CONFIG_CMODE_TRAD   = 0x0000 # Traditional comparator with hysteresis (default)
ADS1015_REG_CONFIG_DR_1600SPS   = 0x0080 # 1600 samples per second (default)
ADS1015_REG_CONFIG_MODE_SINGLE  = 0x0100 # Power-down single-shot mode (default)
ADS1015_REG_CONFIG_GAIN_ONE     = 0x0200 # gain of 1

ADS1015_REG_CONFIG_MUX_SINGLE_0 = 0x4000 # channel 0
ADS1015_REG_CONFIG_MUX_SINGLE_1 = 0x5000 # channel 1
ADS1015_REG_CONFIG_MUX_SINGLE_2 = 0x6000 # channel 2
ADS1015_REG_CONFIG_MUX_SINGLE_3 = 0x7000 # channel 3

ADS1015_REG_CONFIG_OS_SINGLE    = 0x8000 # start a single conversion

ADS1015_REG_CONFIG_CHANNELS = (ADS1015_REG_CONFIG_MUX_SINGLE_0, ADS1015_REG_CONFIG_MUX_SINGLE_1,
			       ADS1015_REG_CONFIG_MUX_SINGLE_2, ADS1015_REG_CONFIG_MUX_SINGLE_3)

BLINK_SOS = '... --- ...'
BLINK_ON = 'Y'
BLINK_OFF = 'N'
BLINK_REDIS = ".-. -.. ..."
current_blink = BLINK_ON
led_is_on = 'X'
BLINK_FAST = '........'

def log(msg):
    sys.stdout.write(str(datetime.now()))
    sys.stdout.write(": ")
    sys.stdout.write(msg)
    sys.stdout.write("\n")
    sys.stdout.flush()

def led_on():
    global led_is_on
    if led_is_on != True:
        os.system('echo 0 > /sys/class/leds/led0/brightness')
        led_is_on = True

def led_off():
    global led_is_on
    if led_is_on != False:
       os.system('echo 1 > /sys/class/leds/led0/brightness')
       led_is_on = False

def blink_dot():
    led_off()
    time.sleep(.1)
    led_on()
    time.sleep(.1)
    led_off()

def blink_dash():
    led_off()
    time.sleep(.1)
    led_on()
    time.sleep(.3)
    led_off()

def blink_long():
    led_on()
    time.sleep(1)
    led_off()

def blink_run():
    global current_blink
    while True:
        for c in current_blink:
            if c == '.':
                blink_dot()
            elif c == '-':
                blink_dash()
            elif c == 'Y':
                blink_long()
            elif c == ' ':
                led_off()
                time.sleep(.2)
            elif c == 'N':
                led_off()
                time.sleep(5)
        time.sleep(1)

def have_internet():
    global config
    conn = httplib.HTTPConnection(config['internet_check'], timeout=5)
    try:
        conn.request("HEAD", "/")
        conn.close()
        log('internet is up')
        return True
    except:
        conn.close()
        log('Internet is down')
        return False

def check_connection(process, service, host=False):
    cmd = "lsof -i -n | grep " + process + " | grep ESTABLISHED | "
    if host:
        cmd += "grep \"" + host + ":" + service + "\""
    else:
        cmd += "grep \":" + service + "\""
    connected = os.system(cmd)
    connected = not bool(os.WEXITSTATUS(connected))
    log("checked service: " + cmd + " :: " + str(connected))
    return connected

def check_internet():
    global current_blink
    os.system("echo none > /sys/class/leds/led0/trigger")
    while True:
        try:
            internet = have_internet()
        except:
            internet = False
        if not internet:
            current_blink = BLINK_SOS
        elif not check_connection("ruby", "http"):
            current_blink = BLINK_FAST
        else:
            current_blink = BLINK_ON
        time.sleep(10)


thread.start_new_thread(check_internet, ())
thread.start_new_thread(blink_run, ())

def ads_read(channel):
  #configdata = bus.read_i2c_block_data(ADS1x15_DEFAULT_ADDRESS, ADS1x15_POINTER_CONFIG, 2) 
  #print("Getting config byte = 0x%02X%02X" % (configdata[0], configdata[1]))

  configword = ADS1015_REG_CONFIG_CQUE_NONE | ADS1015_REG_CONFIG_CLAT_NONLAT | ADS1015_REG_CONFIG_CPOL_ACTVLOW | ADS1015_REG_CONFIG_CMODE_TRAD   |  ADS1015_REG_CONFIG_DR_1600SPS | ADS1015_REG_CONFIG_MODE_SINGLE  | ADS1015_REG_CONFIG_GAIN_ONE | ADS1015_REG_CONFIG_CHANNELS[channel] | ADS1015_REG_CONFIG_OS_SINGLE 
  configdata = [configword >> 8, configword & 0xFF]

  #print("Setting config byte = 0x%02X%02X" % (configdata[0], configdata[1]))
  bus.write_i2c_block_data(ADS1x15_DEFAULT_ADDRESS, ADS1x15_POINTER_CONFIG, configdata)

  configdata = bus.read_i2c_block_data(ADS1x15_DEFAULT_ADDRESS, ADS1x15_POINTER_CONFIG, 2) 
  #print("Getting config byte = 0x%02X%02X" % (configdata[0], configdata[1]))

  while True:
     try:
       configdata = bus.read_i2c_block_data(ADS1x15_DEFAULT_ADDRESS, ADS1x15_POINTER_CONFIG, 2) 
       #print("Getting config byte = 0x%02X%02X" % (configdata[0], configdata[1]))
       if (configdata[0] & 0x80):
         break
     except:
       print("cannot read block")
       pass
  # read data out!
  analogdata = bus.read_i2c_block_data(ADS1x15_DEFAULT_ADDRESS, ADS1x15_POINTER_CONVERSION, 2)
  #print(analogdata),
  retval = (analogdata[0] << 8) | analogdata[1]
  retval /= 16
  #print("-> %d" %retval)
  return retval

######################## main program

bus     = SMBus(1)
HOST = 'localhost'
PORT = 31879
SERVER = socket.socket()
SERVER.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
SERVER.bind((HOST, PORT))
SERVER.listen(10)

# GPIO init
gpio.setwarnings(False)
gpio.setmode(gpio.BCM)
gpio.setup(BUTTONS, gpio.IN, pull_up_down=gpio.PUD_UP)


log("joybonnet starting...");

laserbonnet = None

def accept_connection():
    global laserbonnet, addr
    while True:
        laserbonnet, addr = SERVER.accept()
        print "assigned laserbonnet: " + str(addr)

thread.start_new_thread(accept_connection, ())

def send_sock(msg):
    global laserbonnet

    try:
        if laserbonnet is not None:
            laserbonnet.send(msg.encode('ascii'))
            log("sending msg")

    except:
        log("could not send" + msg.encode('ascii'))
        pass

def close_sock():
    SERVER.close()
atexit.register(close_sock)

def handle_button(pin):
    time.sleep(BOUNCE_TIME)

    if pin >= 1000:
      state = analog_states[pin-1000]
    else:
      state = 0 if gpio.input(pin) else 1

    if state:
        button_states[pin] = True
        send_sock(KEY_PRESS[pin])
    else:
        button_states[pin] = False
        send_sock(KEY_RELEASE[pin])

    if button_states[BUTTON_A] and button_states[START]:
        log("restarting")
        call(["shutdown", "-r", "now"])
    if button_states[BUTTON_B] and button_states[START]:
        log("shutting down")
        call(["shutdown", "-h", "now"])

    if DEBUG:
        log("Pin: {}, KeyCode: {}, Event: {}".format(pin, key, 'press' if state else 'release'))

for button in BUTTONS:
    gpio.add_event_detect(button, gpio.BOTH, callback=handle_button, bouncetime=1)

while True:
  try:
    y = 800 - ads_read(0)
    x = ads_read(1) - 800
  except IOError:
    print("ioerror ads_read")
    continue
  #print("(%d , %d)" % (x, y))

  if (y > ANALOG_THRESH_POS) and not analog_states[0]:
    analog_states[0] = True
    handle_button(1000)      # send UP press
  if (y < ANALOG_THRESH_POS) and analog_states[0]:
    analog_states[0] = False
    handle_button(1000)      # send UP release
  if (y < ANALOG_THRESH_NEG) and not analog_states[1]:
    analog_states[1] = True
    handle_button(1001)      # send DOWN press
  if (y > ANALOG_THRESH_NEG) and analog_states[1]:
    analog_states[1] = False
    handle_button(1001)      # send DOWN release
  if (x < ANALOG_THRESH_NEG) and not analog_states[2]:
    analog_states[2] = True
    handle_button(1002)      # send LEFT press
  if (x > ANALOG_THRESH_NEG) and analog_states[2]:
    analog_states[2] = False
    handle_button(1002)      # send LEFT release
  if (x > ANALOG_THRESH_POS) and not analog_states[3]:
    analog_states[3] = True
    handle_button(1003)      # send RIGHT press
  if (x < ANALOG_THRESH_POS) and analog_states[3]:
    analog_states[3] = False
    handle_button(1003)      # send RIGHT release

  time.sleep(0.01)
