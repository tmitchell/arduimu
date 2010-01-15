// We are using an oversampling and averaging method to increase the ADC resolution
// The theorical ADC resolution is now 11.7 bits. Now we store the ADC readings in float format
void Read_adc_raw(void)
{
  int i;
  int temp1;
  int temp2;
  
  // ADC readings...
  for (i=0;i<6;i++)
    {
    do{
      temp1= analog_buffer[sensors[i]];   // sensors[] maps sensors to correct order 
      temp2= analog_count[sensors[i]];
      } while(temp1 != analog_buffer[sensors[i]]);  // Check if there was an ADC interrupt during readings...
      
    AN[i] = float(temp1)/float(temp2);
    }
  
  // Initialization for the next readings...
  for (int i=0;i<8;i++){
    do{
      analog_buffer[i]=0;
      analog_count[i]=0;
      } while(analog_buffer[i]!=0); // Check if there was an ADC interrupt during initialization...
  }
}

float read_adc(int select)
{
  if (SENSOR_SIGN[select]<0)
    return (AN_OFFSET[select]-AN[select]);
  else
    return (AN[select]-AN_OFFSET[select]);
}

//Activating the ADC interrupts. 
void Analog_Init(void)
{
 ADCSRA|=(1<<ADIE)|(1<<ADEN);
 ADCSRA|= (1<<ADSC);
}

//
void Analog_Reference(uint8_t mode)
{
  analog_reference = mode;
}

//ADC interrupt vector, this piece of code
//is executed everytime a convertion is done. 
ISR(ADC_vect)
{
  volatile uint8_t low, high;
  low = ADCL;
  high = ADCH;

#if PRINT_BINARY == 1  
  analog_buffer[MuxSel] += (high << 8) | low;   // cumulate analog values
  analog_count[MuxSel]++;
#else                                           // if we have a lot of serial output we need to guard against overflows
  if(analog_count[MuxSel]<63) {
    analog_buffer[MuxSel] += (high << 8) | low;   // cumulate analog values
    analog_count[MuxSel]++;
  }
#endif  

  MuxSel++;
  MuxSel &= 0x07;   //if(MuxSel >=8) MuxSel=0;
  ADMUX = (analog_reference << 6) | MuxSel;
  // start the conversion
  ADCSRA|= (1<<ADSC);
}
