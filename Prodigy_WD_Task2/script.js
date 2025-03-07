let seconds = 0;
let tens = 0;
let mins = 0;
let getSeconds = document.querySelector('.seconds');
let getTens = document.querySelector('.tens');
let getMins = document.querySelector('.mins');
let btnStart = document.querySelector('.btn-start');
let btnStop = document.querySelector('.btn-stop');
let btnReset = document.querySelector('.btn-reset');
let btnLap = document.querySelector('.btn-lap');
let interval;
let lapTimes = [];
let lapList = document.createElement('ul'); 
let lapListContainer = document.querySelector('.lap-times-container');

btnStart.addEventListener('click', () => {
    clearInterval(interval);
    interval = setInterval(startTimer, 10);
});

btnStop.addEventListener('click', () => {
    clearInterval(interval);
});

btnReset.addEventListener('click', () => {
    clearInterval(interval);
    tens = 0;
    seconds = 0;
    mins = 0;
    getSeconds.innerHTML = '00';
    getTens.innerHTML = '00';
    getMins.innerHTML = '00';
    lapTimes = []; 
    lapList.innerHTML = '';
});

btnLap.addEventListener('click', () => {    
    lapTimes.push(`${mins}:${seconds}:${tens}`);   
    displayLapTimes();
});

function startTimer() {
    tens++;
    if (tens <= 9) {
        getTens.innerHTML = '0' + tens;
    }
    if (tens > 9) {
        getTens.innerHTML = tens;
    }
    if (tens > 99) {
        seconds++;
        getSeconds.innerHTML = '0' + seconds;
        tens = 0;
        getTens.innerHTML = '00';
    }
    if (seconds > 9) {
        getSeconds.innerHTML = seconds;
    }
    if (seconds > 59) {
        mins++;
        getMins.innerHTML = '0' + mins;
        seconds = 0;
        getSeconds.innerHTML = '00';
    }
    if (mins > 9) {
        getMins.innerHTML = mins;
    }
}

function displayLapTimes() {    
    lapList.innerHTML = '';    
    lapTimes.forEach((lapTime, index) => {
        let lapItem = document.createElement('li');
        lapItem.textContent = `Lap ${index + 1}: ${lapTime}`;
        lapList.appendChild(lapItem);
    });    
    lapListContainer.appendChild(lapList);
}
