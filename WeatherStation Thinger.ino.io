#include <ThingerESP8266.h>
#include <ESP8266WiFi.h>

//Pin Arah angin
#define utara D1
#define tl D8
#define timur D9
#define tenggara D3
#define selatan D4
#define bd D5
#define barat D2
#define bl D7

//rain pin
#include "RTClib.h"
#include <Wire.h>
#include <BH1750.h>
#include "DFRobot_SHT20.h"
#define RainPin D0   

//Kecepatan Angin
#include <Adafruit_ADS1015.h>
BH1750 lightMeter;
DFRobot_SHT20    sht20;
Adafruit_ADS1115 ads(0x48);

struct datapackage{
  float Voltage;
  float kecepatan;
 
};
datapackage data;
float temp,humd,lux;
float yuu;
float kec;
//Curah hujan
bool bucketPositionA = false;             // one of the two positions of tipping-bucket               
const double bucketAmount = 0.053;        // 0.053 inches atau 1.346 mm of rain equivalent of ml to trip tipping-bucket 
double dailyRain = 0.0;                   // rain accumulated for the day
double hourlyRain = 0.0;                  // rain accumulated for one hour
double dailyRain_till_LastHour = 0.0;     // rain accumulated for the day till the last hour          
bool first;                               // as we want readings of the (MHz) loops only at the 0th moment 

RTC_Millis rtc;                           // software RTC time

//Konfigurasi Thinger.io
#define USERNAME "zulpikar"
#define DEVICE_ID "NodeMCU_Angin"
#define DEVICE_CREDENTIAL "geLEXxqWHdZ2"

#define SSID "indiehome"
#define SSID_PASSWORD "aaaaaaaa"
//Variabel untuk Tinger.io
ThingerESP8266 thing(USERNAME, DEVICE_ID, DEVICE_CREDENTIAL);


void setup() {
  Serial.begin(9600);
  //koneksi ke WiFi
  Wire.begin();
  sht20.initSHT20();        // Init SHT20 Sensor
    delay(100);
  lightMeter.begin();
  WiFi.begin(SSID, SSID_PASSWORD);
  //hubungkan NodeMCU ke hinget.io
  thing.add_wifi(SSID, SSID_PASSWORD);
  

//Curah Hujan
  rtc.begin(DateTime(__DATE__, __TIME__));     // start the RTC
  pinMode(RainPin, INPUT);                       // set the Rain Pin as input.
  delay(4000);                                   // wait the serial monitor 
  Serial.println("Rain Gauge Ready !!");         // rain gauge measured per 1 hour           
  Serial.println("execute calculations once per hour !!");

//kecepaan angin
  ads.begin();
  while (!Serial);
  
//arah angin
   Serial.begin(9600);
  pinMode(utara,INPUT_PULLUP);
  pinMode(tl,INPUT_PULLUP);
  pinMode(timur,INPUT_PULLUP);
  pinMode(tenggara,INPUT_PULLUP);
  pinMode(selatan,INPUT_PULLUP);
  pinMode(bd,INPUT_PULLUP);
  pinMode(barat,INPUT_PULLUP);
  pinMode(bl,INPUT_PULLUP);
  

}

float readKecepatan(void)
{
  int16_t adc0;  // we read from the ADC, we have a sixteen bit integer as a result

  adc0 = ads.readADC_SingleEnded(0);
  data.Voltage = (adc0 * 0.1875)/1000;
  if(data.Voltage >= 0.1){
    data.kecepatan = 12*data.Voltage;
  }
  else if (data.Voltage < 0.2){
    data.kecepatan = 0;
  }
  float kec = data.kecepatan*(3600/1000);
  return(kec);}

void loop() {
  thing.handle();
   humd = sht20.readHumidity();                  // Read Humidity
  temp = sht20.readTemperature();
  lux = lightMeter.readLightLevel();
  yuu = readKecepatan();
  //curah hujan
  DateTime now = rtc.now();
  // ++++++++++++++++++++++++ Count the bucket tips ++++++++++++++++++++++++++++++++
  if ((bucketPositionA==false)&&(digitalRead(RainPin)==LOW)){
    bucketPositionA=true;
    dailyRain+=bucketAmount;                               // update the daily rain
  }
  
  if ((bucketPositionA==true)&&(digitalRead(RainPin)==HIGH)){
    bucketPositionA=false;  
  } 
  // +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  
  if(now.minute() != 0) first = true;                     // after the first minute is over, be ready for next read
  
 // if(now.minute() == 0 && first == true){
 
    hourlyRain = dailyRain - dailyRain_till_LastHour;      // calculate the last hour's rain 
    dailyRain_till_LastHour = dailyRain;                   // update the rain till last hour for next calculation
    
    // fancy display for humans to comprehend
    Serial.println();
    Serial.print(now.hour());
    Serial.print(":");
    Serial.print(now.minute());
    Serial.print(":  Total Rain for the day = ");
    Serial.print(dailyRain,3);                            // the '3' ensures the required accuracy digit dibelakang koma
    Serial.print(" inches atau ");
    Serial.print(dailyRain*2.54*10,3);
    Serial.println(" mm");
    Serial.println();
    Serial.print("     :  Rain in last hour = ");
    Serial.print(hourlyRain,3); 
    Serial.print(" inches atau ");
    Serial.print(hourlyRain*2.54*10,3);
    Serial.println(" mm"); 
    Serial.println();
      thing["hujan"] >> [](pson&out){
      out["JAM CURAH HUJAN"] = hourlyRain*2.54*10;
      out["TOTAL CURAH HUJAN"] = dailyRain*2.54*10;
                                        };  

    first = false;    
                                    // execute calculations only once per hour
 // }
  
  if(now.hour()== 0) {
    dailyRain = 0.0;                                      // clear daily-rain at midnight
    dailyRain_till_LastHour = 0.0;                        // we do not want negative rain at 01:00
  }

  Serial.print("\tSpeed: ");
  Serial.print(yuu, 2);   
  Serial.println(" km/h");

thing["cuaca"] >> [](pson&out){
   if(digitalRead(selatan)==LOW)
  {
    Serial.println("ARAH ANGIN : SELATAN");
       out["utara"] ="selatan";
    }
    else if(digitalRead(timur)==LOW)
    {
      Serial.println("ARAH ANGIN : TIMUR");
        out["utara"] ="timur";
      }
     else if(digitalRead(tl)==LOW)
    {
      Serial.println("ARAH ANGIN : TIMUR LAUT");
        out["utara"] ="timur laut";
      }
      else if(digitalRead(bd)==LOW)
    {
      Serial.println("ARAH ANGIN : BARAT DAYA");
        out["utara"] ="barat daya";
      }
      else if(digitalRead(bl)==LOW)
    {
      Serial.println("ARAH ANGIN : BARAT LAUT");
        out["utara"] ="barat laut";
      }
      else if(digitalRead(tenggara)==LOW)
    {
      Serial.println("ARAH ANGIN : TENGGARA");
        out["utara"] ="tenggara";
      }
      else if(digitalRead(barat)==LOW)
    {
      Serial.println("ARAH ANGIN : BARAT");
        out["utara"] ="barat";
      }
      
      else if(digitalRead(utara)==LOW)
    {
    Serial.println("ARAH ANGIN : UTARA");
      out["utara"] ="utara";
    }
     delay (100); 
//    out["tl"] = tl;
//   
//    out["tenggara"] = tenggara;
//    out["selatan"] = selatan;
//    out["bd"] = bd;
//    out["barat"] = barat;
//    out["bl"] = bl;
      out["kelembapan"] = humd;
      out["suhu"] = temp;
      out["cahaya"] = lux;                        
      out["KECEPATAN ANGIN"] = yuu;


};

 //arah angin
//  if(digitalRead(utara)==LOW){Serial.println("ARAH ANGIN : UTARA");}

//  if(digitalRead(utara)==LOW)
//    {
//    Serial.println("ARAH ANGIN : UTARA");
//  
//    }
// if(digitalRead(tl)==LOW){Serial.println("ARAH ANGIN : TIMUR LAUT");}
//
//else if(digitalRead(tenggara)==LOW){Serial.println("ARAH ANGIN : TENGGARA");}
//else if(digitalRead(selatan)==LOW){Serial.println("ARAH ANGIN : SELATAN");}
//else if(digitalRead(bd)==LOW){Serial.println("ARAH ANGIN : BARAT DAYA");}
//else if(digitalRead(barat)==LOW){Serial.println("ARAH ANGIN : BARAT");}
//else if(digitalRead(bl)==LOW){Serial.println("ARAH ANGIN : BARAT LAUT");}
 

}
