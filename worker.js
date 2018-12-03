addEventListener('fetch', event => {
  event.respondWith(getLEDAndMotorStatus(event))
})

async function getLEDAndMotorStatus(event) {
  const url = new URL(event.request.url)

  if (!url.searchParams.has("token")) {
    return new Response("Missing parameter 'token'", {status: 403})
  }

  const token = url.searchParams.get("token")

  if (token != "<SECRET>") {
      return new Response("Invalid parameter 'token'", {status: 401})  
  }

  let today = new Date()
  let led = "off"
  let motor = "off"

  // On a weekday at 0743 switch on the LED to warm that it's almost
  // time to get the bus, at 0744 flash the LED to indicate that time
  // is running out and at 0745 rotate the reflector to say it's time
  // to go

  if ((today.getDay() > 0) && (today.getDay() < 6)) {
    if (today.getHours() == 7) {
      switch (today.getMinutes()) {
        case 43:
          led = "steady"
          break
        case 44:
          led = "flashing"
          break
        case 45:
          led = "steady"
          motor = "on"
          break
      }
    }
  }

  let json = { "motor": motor, "led": led}

  return new Response(JSON.stringify(json), {headers: {"Content-Type": "application/json"}})
}
