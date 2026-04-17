// Define pin locations
const int lightPin = A0;
const int pirPin = 2;
const int trigPin = 9;
const int echoPin = 10;

// Read distance (in cm) from ultrasonic sensor
long readDistanceCm() {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);

  // Emit ultrasonic wave via 10ms HIGH pulse
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  // Measures how long echo pin stays HIGH
  long duration = pulseIn(echoPin, HIGH, 30000);

  // Handles when no echo is recieved
  if (duration == 0) {
    return -1;
  }

  // Convert time to distance
  long distanceCm = duration * 0.0343 / 2.0;
  return distanceCm;
}

void setup() {
  Serial.begin(9600);

  pinMode(pirPin, INPUT);
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
}

void loop() {
  int lightValue = analogRead(lightPin);
  int motionValue = digitalRead(pirPin);
  long distanceCm = readDistanceCm();

  // Output the values in the following order: distance,light,motion
  Serial.print(distanceCm);
  Serial.print(",");
  Serial.print(lightValue);
  Serial.print(",");
  Serial.println(motionValue);

  delay(1000);
}
