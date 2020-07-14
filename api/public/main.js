const socket = io();

socket.on('hostname', (event) => {
  window.document.getElementById('hostname').innerText = event;
});
