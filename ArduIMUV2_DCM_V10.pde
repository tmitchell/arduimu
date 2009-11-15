//Released under Creative Commons License 
// Code by Jordi Munoz and William Premerlani, Supported by Chris Anderson and Nathan Sindle (SparkFun).
//Version 1.0 for flat board updated by Doug Weibel to correct coordinate system, correct pitch/roll drift cancellation, correct yaw drift cancellation and fix minor gps bug.

#define GRAVITY 101 //this equivalent to 1G in the raw data coming from the accelerometer 
#define Accel_Scale(x) x*(GRAVITY/9.81)//Scaling the raw data of the accel to actual acceleration in meters for seconds square

#define Gyro_Gain 2.5 //2.5Gyro gain
#define Gyro_Scaled(x) x*((Gyro_Gain*PI)/360)//Return the scaled ADC raw data of the gyro in radians for second
#define G_Dt(x) x*.02 //DT .02 = 20 miliseconds, value used in derivations and integrations

#define ToRad(x) (x*PI)/180.0
#define ToDeg(x) (x*180.0)/PI

#define Kp_ROLLPITCH 0.015 //.015 Pitch&Roll Proportional Gain
#define Ki_ROLLPITCH 0.000010 //0.000005Pitch&Roll Integrator Gain
#define Kp_YAW .5 //.5Yaw Porportional Gain  
#define Ki_YAW 0.0005 //0.0005Yaw Integrator Gain

/*Min Speed Filter for Yaw Correction*/
#define SPEEDFILT 1 //1=use min speed filter for yaw drift cancellation, 0=do not use

/*For debugging propurses*/
#define OMEGAA 1 //If value = 1 will print the corrected data, 0 will print uncorrected data of the gyros (with drift)
#define PRINT_DCM 1 //Will print the whole direction cosine matrix
#define PRINT_ANALOGS 1 // If 1 will print the analog raw data
#define PRINT_EULER 1 //Will print the Euler angles Roll, Pitch and Yaw
#define PRINT_GPS 0

#define ADC_WARM_CYCLES 75

//Sensor: GYROX, GYROY, GYROZ, ACCELX, ACCELY, ACCELZ
float SENSOR_SIGN[]={1,-1,-1,-1,1,-1}; //{1,1,-1,1,-1,1}Used to change the polarity of the sensors{-1,1,-1,-1,-1,1}

int long timer=0; //general porpuse timer 
int long timer24=0; //Second timer used to print values 
int AN[8]; //array that store the 6 ADC filtered data
int AN_OFFSET[8]; //Array that stores the Offset of the gyros
int EX[8]; //General porpuse array to send information

float Accel_Vector[3]= {0,0,0}; //Store the acceleration in a vector
float Gyro_Vector[3]= {0,0,0};//Store the gyros rutn rate in a vector
float Omega_Vector[3]= {0,0,0}; //Corrected Gyro_Vector data
float Omega_P[3]= {0,0,0};//Omega Proportional correction
float Omega_I[3]= {0,0,0};//Omega Integrator
float Omega[3]= {0,0,0};

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
float lat=0; // store the Latitude from the gps
float lon=0;// Store guess what?
float alt_MSL=0; //This is the alt.
float ground_speed=0;// This is the velocity your "plane" is traveling in meters for second, 1Meters/Second= 3.6Km/H = 1.944 knots
float ground_course=90;//This is the runaway direction of you "plane" in degrees
float climb_rate=0; //This is the velocity you plane will impact the ground (in case of being negative) in meters for seconds
char data_update_event=0; 

//uBlox Checksum
byte ck_a=0;
byte ck_b=0;
long iTOW=0; //GPS Millisecond Time of Week
long alt=0; //Height above Ellipsoid 
float speed_3d=0; //Speed (3-D)  (not used)


volatile uint8_t MuxSel=0;
volatile uint8_t analog_reference = DEFAULT;
volatile int16_t analog_buffer[8];

void test(float value[9],int pos)
{
  Serial.print(convert_to_dec(value[pos]));
}

void setup()
{
  Serial.begin(38400);
  pinMode(2,OUTPUT); //Serial Mux
  digitalWrite(2,HIGH); //Serial Mux
  pinMode(5,OUTPUT); //Red LED
  pinMode(6,OUTPUT); // BLue LED
  pinMode(7,OUTPUT); // Yellow LED
  Analog_Reference(EXTERNAL);//Using external analog reference
  Analog_Init();
  
  
  for(int c=0; c<ADC_WARM_CYCLES; c++)
  {
    read_adc_raw();
    
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
  
  for(int y=0; y<=7; y++)
  {
    AN_OFFSET[y]=AN[y];
    Serial.println((int)AN_OFFSET[y]);
  }
    AN_OFFSET[5]=AN[5]-GRAVITY;
  //Matrix_Multiply(experiment, experiment2, experiment3);

}

void loop()//Main Loop
{
  
  //counter++;
  if((millis()-timer)>=20)
  {
    timer=millis();
    read_adc_raw(); //ADC Stuff
    Matrix_update(); 
    Normalize();
    roll_pitch_drift();
    
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
    printdata(); //Send info via serial
  }
}
