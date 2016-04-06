<!DOCTYPE html>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>

<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" type="text/css" href="<c:url value='/css/bootstrap.min.css'/>"/>
    <link rel="stylesheet" type="text/css" href="<c:url value='/css/fourstate.css'/>"/>
    <script src="<c:url value='/scripts/jquery-2.1.4.js'/>"></script>
    <script src="<c:url value='/scripts/fourstate.js'/>"></script>

    <style>
        .scanner {
            width: 640px;
            height: 50px;
            overflow: hidden;
            display: block;
            border-style: solid;
            border-width: 5px;

        }
        .scanner-scanning {
            border-color: yellow;
        }
        .scanner-success {
            border-color: green;
        }
        .scanner-failed {
            border-color: red;
        }
        .overlay {
            margin-left: 5px;
            margin-top: -25px;
            margin-bottom: 25px;
            width: 630px;
            height: 1px;
            border-style: solid;
            border-width: 2px;
            border-color: green;
            z-index: 2147483647;
            opacity: 0.5;
        }

        #video {
            margin-top: -215px;
        }
    </style>

    <title>Barcode recognition with JavaScript</title>
    <script>
        // H = Full bar
        // A = Ascender
        // D = Descender
        // T = Tracking (short bar)
        var barcodeStateDigits = [];
        barcodeStateDigits["HH"] = "0";
        barcodeStateDigits["HA"] = "1";
        barcodeStateDigits["HD"] = "2";
        barcodeStateDigits["AH"] = "3";
        barcodeStateDigits["AA"] = "4";
        barcodeStateDigits["AD"] = "5";
        barcodeStateDigits["DH"] = "6";
        barcodeStateDigits["DA"] = "7";
        barcodeStateDigits["DD"] = "8";
        barcodeStateDigits["TH"] = "9";

        var cameraWidth = 640;
        var cameraHeight = 480;
        var scannerHeight = 50;
        var barWidth = 3;
        var barCentreOffset = Math.floor(barWidth / 2);
        var barBrightnessThreshold = 80;
        var barLengthTolerancePercent = 0.20;
        var scanSound = new Audio('sounds/scannerBeep.mp3');

        var scanTimer;

        var canvas = document.createElement('canvas');
        canvas.width = cameraWidth;
        canvas.height = cameraHeight;

        function scan() {
            $("#scanner").removeClass("scanner-success scanner-failed");
            $("#scanner").addClass("scanner-scanning");
            var doc = document,
                img = doc.getElementById("barcode"),
                width = canvas.width,
                height = canvas.height,
                ctx = canvas.getContext("2d");
            // Capture the image
            ctx.drawImage(video, 0, Math.floor((cameraHeight - scannerHeight) / 2),
                cameraWidth, scannerHeight, 0, 0, cameraWidth, scannerHeight);

            var row = Math.round(scannerHeight/2);

            // This function is extremely slow on mobile, so we need to only do it once
            // and then work with the data we get back using a local function
            var imageData = ctx.getImageData(0, 0, width, height).data;
            var success = false;
            for (var i = -1; i <= 1; i++) {
                var result = scanRow(imageData, row + i, width);
                if (result.bars.length == 37 || result.bars.length == 52 || result.bars.length == 67) {
                    if (decodeResult(result)) {
                        $("#scanner").removeClass("scanner-scanning scanner-failed");
                        $("#scanner").addClass("scanner-success");
                        clearInterval(scanTimer);
                        var interval = setInterval(function() {
                            clearInterval(interval);
                            scanTimer = setInterval(function() {
                                scan();
                            }, 200);
                        }, 1000);
                        success = true;
                        break;
                    }
                }
            }
            if (!success) {
                $("#scanner").addClass("scanner-failed");
                $("#scanner").removeClass("scanner-success scanner-scanning");
            }
        }

        function scanRow(imageData, row, width) {
            var pixels = getImageData(imageData, width, 0, row, width, 1);

            currentBar = false;
            var barStartCol = 0;
            var barEndCol = 0;

            var highestY = -1;
            var lowestY = 999;
            var bars = [];
            var barIndex = 0;

            for (var col = 0; col < width; col++) {
                var red = pixels[col * 4];
                var green = pixels[(col * 4) + 1];
                var blue = pixels[(col * 4) + 2];
                var brightness = fnBrightness(red, green, blue);
                if (!currentBar && brightness < barBrightnessThreshold) {
                    currentBar = true;
                    barStartCol = col;
                } else if (currentBar && brightness > barBrightnessThreshold) {
                    // We are at the end of a bar
                    currentBar = false;
                    barEndCol = col - 1;
                    var barMidCol = Math.round(barStartCol + ((barEndCol - barStartCol) / 2))   ;

                    var minY = 999;
                    var maxY = -1;

                    for (var y = 0; y < scannerHeight; y++) {
                        var barPixels = getImageData(imageData, width, barMidCol - barCentreOffset, y, barWidth, 1);

                        // Is any pixel in this row dark?
                        for (var x = 0; x < barWidth; x++) {
                            if (fnBrightness(barPixels[x*4], barPixels[(x*4)+1], barPixels[(x*4)+2]) < barBrightnessThreshold) {
                                if (y < minY) minY = y;
                                if (y > maxY) maxY = y;
                                break;
                            }
                        }
                    }
                    if (minY < lowestY) lowestY = minY;
                    if (maxY > highestY) highestY = maxY;

                    var bar = {};
                    bar.minY = minY;
                    bar.maxY = maxY;
                    bars.push(bar);
                }
            }
            var result = {};
            result.lowestY = lowestY;
            result.highestY = highestY;
            result.bars = bars;
            return result;
        }

        function decodeResult(result) {
            var fullBarLength = result.highestY - result.lowestY;
            var barTolerance = fullBarLength * barLengthTolerancePercent;

            var barString = "";

            for (var i = 0; i < result.bars.length; i++) {
                var topBar = false;
                var bottomBar = false;
                if (result.bars[i].minY - result.lowestY <= barTolerance) {
                    topBar = true;
                }
                if (result.highestY - result.bars[i].maxY <= barTolerance) {
                    bottomBar = true;
                }

                if (topBar && bottomBar) {
                    barString += "H";
                } else if (topBar && !bottomBar) {
                    barString += "A";
                } else if (!topBar && bottomBar) {
                    barString += "D";
                } else {
                    barString += "T";
                }
            }
            if (barString.startsWith("AT") && barString.endsWith("AT")) {
                var dpid = "";
                for (var i = 6; i < 21; i+=2) {
                    var pair = barString.substring(i, i + 2);
                    dpid += barcodeStateDigits[pair];
                }
                console.log("dpid=" + dpid);
                $("#dpid").text(dpid);
                lookupAddress(dpid, function(deliveryPoint) {
                    $("#address").html(deliveryPoint.addressLine1 + "<br/>" + deliveryPoint.addressLine2);
                });
                scanSound.play();
                return true;
            }
            return false;
        }

        function getImageData(fullImageData, imageWidth, x, y, width, height) {
            var retVal = [];
            for (var row = y; row < row + height; row++) {
                for (var col = x; col < x + width; col++) {
                    for (var pixel = 0; pixel < 4; pixel++) {
                        retVal.push(fullImageData[(row*imageWidth*4) + (col*4) + pixel]);
                    }
                }
                return retVal;
            }
        }

        function fnBrightness(red, green, blue) {
            return (0.33 * red) + (0.5 * green) + (0.16 * blue);
        }

        function init() {
            MediaStreamTrack.getSources(gotSources);
            scanTimer = setInterval(function() {
                scan();
            }, 200);
        }

        function gotSources(sourceInfos) {
          for (var i = 0; i !== sourceInfos.length; ++i) {
            var sourceInfo = sourceInfos[i];
            var option = document.createElement('option');
            option.value = sourceInfo.id;
            if (sourceInfo.kind === 'video') {
                if (sourceInfo.label.indexOf("back") > -1) {
                    sourceSelected(sourceInfo.id);
                    return;
                }
            }
          }
          // Didn't find a back camera so use the first one
          for (var i = 0; i !== sourceInfos.length; ++i) {
            var sourceInfo = sourceInfos[i];
            var option = document.createElement('option');
            option.value = sourceInfo.id;
            if (sourceInfo.kind === 'video') {
                sourceSelected(sourceInfo.id);
                break;
            }
          }
        }

        function sourceSelected(videoSource) {
            var constraints = {
                video: {
                    optional: [{sourceId: videoSource}]
                }
            }

            // Grab elements, create settings, etc.
            var video = document.getElementById("video"),
                errBack = function(error) {
                    console.log("Video capture error: ", error.code);
                };

            // Put video listeners into place
            if(navigator.getUserMedia) { // Standard
                navigator.getUserMedia(constraints, function(stream) {
                    video.src = stream;
                    video.play();
                }, errBack);
            } else if(navigator.webkitGetUserMedia) { // WebKit-prefixed
                navigator.webkitGetUserMedia(constraints, function(stream){
                    video.src = window.webkitURL.createObjectURL(stream);
                    video.play();
                }, errBack);
            }
            else if(navigator.mozGetUserMedia) { // Firefox-prefixed
                navigator.mozGetUserMedia(constraints, function(stream){
                    video.src = window.URL.createObjectURL(stream);
                    video.play();
                }, errBack);
            }
        }
        jQuery(document).ready(function ($) {
            init();
        });
    </script>
</head>

<body>
    <div class="container">
        <div class="row">
            <div id="scanner" class="scanner scanner-failed">
                <video id="video" width="640" autoplay translate="false"/>
            </div>
            <div class="overlay" />
        </div>
        <div class="row address">
            <div class="col-xs-3">
                <span id="dpid">DPID</span>
            </div>
            <div class="col-xs-9">
                <span id="address">Address</span>
            </div>
        </div>
    </div>
</body>
</html>
