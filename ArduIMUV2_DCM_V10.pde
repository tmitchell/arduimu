// Released under Creative Commons License 
// Code by Jordi Munoz and William Premerlani, Supported by Chris Anderson and Nathan Sindle (SparkFun).
// Version 1.0 for flat board updated by Doug Weibel and Jose Julio

// Axis definition: X axis pointing forward, Y axis pointing to the right and Z axis pointing down.
// Positive pitch : nose up
// Positive roll : right wing down
// Positive yaw : clockwise

// Hardware version - Can be used for v1 (daughterboards) or v2 (flat)
// Select the correct statements at line 53

// ADC : Voltage reference 3.3v / 10bits(1024 steps) => 3.22mV/ADC step
// ADXL335 Sensitivity(from datasheet) => 330mV/g, 3.22mV/ADC step => 330/3.22 = 102.48
// Tested value : 101
#define GRAVITY 101 //this equivalent to 1G in the raw data coming from the accelerometer 
#define Accel_Scale(x) x*(GRAVITY/9.81)//Scaling the raw data of the accel to actual acceleration in meters for seconds square

#define ToRad(x) (x*0.01745329252)  // *pi/180
#define ToDeg(x) (x*57.2957795131)  // *180/pi

// LPR530 & LY530 Sensitivity (from datasheet) => 3.33mV/º/s, 3.22mV/ADC step => 1.03
// Tested values : 0.96,0.96,0.94
#define Gyro_Gain_X 0.92 //X axis Gyro gain
#define Gyro_Gain_Y 0.92 //Y axis Gyro gain
#define Gyro_Gain_Z 0.94 //Z axis Gyro gain
#define Gyro_Scaled_X(x) x*ToRad(Gyro_Gain_X) //Return the scaled ADC raw data of the gyro in radians for second
#define Gyro_Scaled_Y(x) x*ToRad(Gyro_Gain_Y) //Return the scaled ADC raw data of the gyro in radians for second
#define Gyro_Scaled_Z(x) x*ToRad(Gyro_Gain_Z) //Return the scaled ADC raw data of the gyro in radians for second

#define Kp_ROLLPITCH 0.015
#define Ki_ROLLPITCH 0.000010
#define Kp_YAW .5
#define Ki_YAW 0.00005

/*Min Speed Filter for Yaw drift Correction*/
#define SPEEDFILT 2 // >1 use min speed filter for yaw drift cancellation, 0=do not use speed filter

/*For debugging propurses*/
//OUTPUTMODE=1 will print the corrected data, 0 will print uncorrected data of the gyros (with drift), 2 will print accelerometer only data
#define OUTPUTMODE 1

#define PRINT_DCM 0     //Will print the whole direction cosine matrix
#define PRINT_ANALOGS 0 //Will print the analog raw data
#define PRINT_EULER 1   //Will print the Euler angles Roll, Pitch and Yaw
#define PRINT_GPS 0     //Will print GPS data
#define PRINT_BINARY 0  //Will print binary message and suppress ASCII messages (above)

#define ADC_WARM_CYCLES 75

/*Select hardware version - comment out one pair below*/

//  uint8_t sensors[6] = {0,2,1,3,5,4};   // Use these two lines for Hardware v1 (w/ daughterboards)
//  int SENSOR_SIGN[]= {1,-1,1,-1,1,1};  //Sensor: GYROX, GYROY, GYROZ, ACCELX, ACCELY, ACCELZ

  uint8_t sensors[6] = {6,7,3,0,1,2};  // For Hardware v2 flat
  int SENSOR_SIGN[] = {1,-1,-1,1,-1,1};

float G_Dt=0.02;    // Integration time (DCM algorithm)

long timer=0;   //general porpuse timer
long timer_old;
long timer24=0; //Second timer used to print values 
float AN[8]; //array that store the 6 ADC filtered data
float AN_OFFSET[8]; //Array that stores the Offset of the gyros

float Accel_Vector[3]= {0,0,0}; //Store the acceleration in a vector
float Gyro_Vector[3]= {0,0,0};//Store the gyros rutn rate in a vector
float Omega_Vector[3]= {0,0,0}; //Corrected Gyro_Vector data
float Omega_P[3]= {0,0,0};//Omega Proportional correction
float Omega_I[3]= {0,0,0};//Omega Integrator
float Omega[3]= {0,0,0};

// Euler angles
float roll;
float pitch;
float yaw;

float errorRollPitch[3]= {0,0,0}; 
float errorYaw[3]= {0,0,0};
float errorCourse=180; 
float COGX=0; //Course overground X axis
float COGY=1; //Course overground Y axis

unsigned int counter=0;
byte gyro_sat=0;

float DCM_Matrix[3][3]= {
  {
    1,0,0  }
  ,{
    0,1,0  }
  ,{
    0,0,1  }
}; 
float Update_Matrix[3][3]={{0,1,2},{3,4,5},{6,7,8}}; //Gyros here


float Temporary_Matrix[3][3]={
  {
    0,0,0  }
  ,{
    0,0,0  }
  ,{
    0,0,0  }
};
 
//GPS 

//GPS stuff
union long_union {
	int32_t dword;
	uint8_t  byte[4];
} longUnion;

union int_union {
	int16_t word;
	uint8_t  byte[2];
} intUnion;

/*Flight GPS variables*/
int gpsFix=1; //This variable store the status of the GPS
int gpsFixnew=0; //used to flag when new gps data received - used for binary output message flags
float lat=0; // store the Latitude from the gps
float lon=0;// Store guess what?
float alt_MSL=0; //This is the alt.
long iTOW=0; //GPS Millisecond Time of Week
long alt=0;  //Height above Ellipsoid 
float speed_3d=0; //Speed (3-D)
float ground_speed=0;// This is the velocity your "plane" is traveling in meters for second, 1Meters/Second= 3.6Km/H = 1.944 knots
float ground_course=90;//This is the runaway direction of you "plane" in degrees
char data_update_event=0; 

// GPS UBLOX
byte ck_a=0;    // Packet checksum
byte ck_b=0;
byte UBX_step=0;
byte UBX_class=0;
byte UBX_id=0;
byte UBX_payload_length_hi=0;
byte UBX_payload_length_lo=0;
byte UBX_payload_counter=0;
byte UBX_buffer[40];
byte UBX_ck_a=0;
byte UBX_ck_b=0;

//ADC variables
volatile uint8_t MuxSel=0;
volatile uint8_t analog_reference = DEFAULT;
volatile uint16_t analog_buffer[8];
volatile uint8_t analog_count[8];

void setup()
{ 
  Serial.begin(38400);
  pinMode(2,OUTPUT); //Serial Mux
  digitalWrite(2,HIGH); //Serial Mux
  pinMode(5,OUTPUT); //Red LED
  pinMode(6,OUTPUT); // BLue LED
  pinMode(7,OUTPUT); // Yellow LED
  pinMode(9,OUTPUT);
  
  Analog_Reference(EXTERNAL);//Using external analog reference
  Analog_Init();
  Serial.println("ArduIMU");
  
  for(int c=0; c<ADC_WARM_CYCLES; c++)
  { 
    digitalWrite(7,LOW);
    digitalWrite(6,HIGH);
    digitalWrite(5,LOW);
    delay(50);
    digitalWrite(7,HIGH);
    digitalWrite(6,LOW);
    digitalWrite(5,HIGH);
    delay(50);
  }
  digitalWrite(5,LOW);
  digitalWrite(7,LOW);
  
  Read_adc_raw();
  delay(20);
  Read_adc_raw();
  for(int y=0; y<=5; y++)   // Read first initial ADC values for offset.
    AN_OFFSET[y]=AN[y];
  delay(20);
  for(int i=0;i<400;i++)    // We take some readings...
    {
    Read_adc_raw();
    for(int y=0; y<=5; y++)   // Read initial ADC values for offset (averaging).
      AN_OFFSET[y]=AN_OFFSET[y]*0.8 + AN[y]*0.2;
    delay(20);
    }
  AN_OFFSET[5]-=GRAVITY;
  for(int y=0; y<=5; y++)
    Serial.println(AN_OFFSET[y]);
  
  delay(250);
    
  Read_adc_raw();     // ADC initialization
  timer=millis();
  delay(20);
}

int debug_t1;
int debug_t2;

void loop() //Main Loop
{
 
  if((millis()-timer)>=20)  // Main loop runs at 50Hz
  {
    timer_old = timer;
    timer=millis();
    G_Dt = (timer-timer_old)/1000.0;    // Real time of loop run. We use this on the DCM algorithm (gyro integration time)
    
    // *** DCM algorithm
    Read_adc_raw();
    Matrix_update(); 
    Normalize();
    Drift_correction();
    Euler_angles();
    #if PRINT_BINARY
      printdata(); //Send info via serial
    #endif


    // ***
    
    //Turn on the LED when you saturate any of the gyros.
    if((abs(Gyro_Vector[0])>=ToRad(300))||(abs(Gyro_Vector[1])>=ToRad(300))||(abs(Gyro_Vector[2])>=ToRad(300)))
    {
      gyro_sat=1;
      digitalWrite(5,HIGH);  
    }
  }
  
  if((millis()-timer24)>=100)
  {
    if(gyro_sat>=1)
    {
      digitalWrite(5,HIGH);
      if(gyro_sat>=8)
        gyro_sat=0;
      else
        gyro_sat++;
    }
    else
    {
      digitalWrite(5,LOW);
    }
    timer24=millis();
    decode_gps();
    #if !PRINT_BINARY
      printdata(); //Send info via serial
    #endif
  }
  
}
