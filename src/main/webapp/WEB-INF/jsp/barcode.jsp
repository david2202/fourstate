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
        label{display:block}

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
            margin-top: -27px;
            margin-bottom: 23px;
            width: 630px;
            height: 2px;
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

    <title>Customer Barcode Quality Assurance</title>
    <script>
        var cameraWidth = 640;
        var cameraHeight = 480;
        var scannerHeight = 50;
        var scanRows = 4;
        var maxBarWidth = Math.ceil(cameraWidth / 67 / 2); // 67 column barcode with spaces
        var barCentreOffset = Math.floor(maxBarWidth / 2);
        var barBrightnessThreshold = 80;
        var barLengthTolerancePercent = 0.20;
        var scanSound = new Audio('http://' + window.location.hostname + ':${httpPort}/sounds/scannerBeep.mp3');

        var scanTimer;

        var canvas = document.createElement('canvas');
        canvas.width = cameraWidth;
        canvas.height = scannerHeight;

        function scan() {
            $("#scanner").removeClass("scanner-success scanner-failed").addClass("scanner-scanning");
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
            // and then work with the data we get back using the local function getPixel
            var imageData = ctx.getImageData(0, 0, width, height).data;
            var success = false;
            for (var i = (scanRows / -2); i <= (scanRows / 2) - 1; i++) {
                var result = scanRow(imageData, row + i, width);
                if (result.bars.length == 37 || result.bars.length == 52 || result.bars.length == 67) {
                    if (decodeResult(result)) {
                        $("#scanner").removeClass("scanner-scanning scanner-failed").addClass("scanner-success");
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
                $("#scanner").removeClass("scanner-success scanner-scanning").addClass("scanner-failed");
            }
        }

        function scanRow(imageData, row, width) {
            var currentBar = false;
            var barStartCol = 0;
            var barEndCol = 0;

            var highestY = -1;
            var lowestY = 999;
            var bars = [];

            for (var col = 0; col < width; col++) {
                var pixel = getPixel(imageData, width, col, row);
                var brightness = fnBrightness(pixel[0], pixel[1], pixel[2]);
                if (!currentBar && brightness <= barBrightnessThreshold) {
                    // We're not currently in a bar and this pixel is dark enough to be a bar
                    currentBar = true;
                    barStartCol = col;
                } else if (currentBar && brightness > barBrightnessThreshold) {
                    // We are at the end of a bar
                    currentBar = false;
                    barEndCol = col - 1;
                    var barWidth = barEndCol - barStartCol + 1;
                    if (barWidth > maxBarWidth) {
                        // Too wide to be a bar, so start again
                        bars = [];
                        var highestY = -1;
                        var lowestY = 999;
                    } else {
                        // We've got a bar, so measure how high it is
                        var minY = 999;
                        var maxY = -1;

                        for (var y = 0; y < scannerHeight; y++) {
                            // Is any pixel in this row dark?
                            for (var x = barStartCol; x <= barEndCol; x++) {
                                var barPixel = getPixel(imageData, width, x, y);
                                if (fnBrightness(barPixel[0], barPixel[1], barPixel[2]) < barBrightnessThreshold) {
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
                var inf = do_decode(barString);
                show_barcode(inf);
                var status = inf.message;;
                var dpid;

                if (inf.damaged) {
                    var correctedInf = do_decode(inf.barcode2);
                    dpid = correctedInf.dpid;
                } else {
                    dpid = inf.dpid;
                }
                console.log("dpid=" + dpid);
                $("#dpid").text(dpid);
                $("#status").text(status);
                lookupAddress(dpid,
                    function(deliveryPoint) {
                        $("#address").html(deliveryPoint.addressLine1 + "<br/>" + deliveryPoint.addressLine2);
                        if (inf.damaged || inf.format_type === "Unknown Format Code") {
                            $("#statusDiv").removeClass("success failure").addClass("problem");
                        } else {
                            $("#statusDiv").removeClass("problem failure").addClass("success");
                        }
                    },
                    function(jqXHR, errorType, exception) {
                        $("#statusDiv").removeClass("success failure").addClass("problem");
                        if (jqXHR.status && jqXHR.status==404) {
                            $("#address").text("Not Found");
                        } else {
                            $("#address").text(errorType);
                        }
                    }
                );
                scanSound.play();
                return true;
            }
            return false;
        }

        function getPixel(fullImageData, imageWidth, x, y) {
            var pixel = [];
            for (var i = 0; i < 4; i++) {
                var pos = (y*imageWidth*4) + (x*4) + i;
                pixel[i] = fullImageData[(y*imageWidth*4) + (x*4) + i];
            }
            return pixel;
        }

        function fnBrightness(red, green, blue) {
            return (0.33 * red) + (0.5 * green) + (0.16 * blue);
        }

        function init() {
            MediaStreamTrack.getSources(gotSources);

            scanTimer = setInterval(function() {
                scan();
            }, 200);

            $("#video").click(function(event) {
                scanSound.play();
            });
        }

        function gotSources(sourceInfos) {
            for (var i = 0; i !== sourceInfos.length; ++i) {
                var sourceInfo = sourceInfos[i];
                var option = document.createElement('option');
                option.value = sourceInfo.id;
                if (sourceInfo.kind === 'video') {
                    if (sourceInfo.facing === 'environment' || sourceInfo.label.indexOf('back') > -1) {
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
        <div class="row">
            <div class="col-xs-10">
                <script>generateBarcodeTable();</script>
            </div>
            <div id="dpidDiv" class="col-xs-2">
                <label for="dpid" class="control-label">DPID</label>
                <span id="dpid" />
            </div>
        </div>
        <div class="row address">
            <div id="addressDiv" class="col-xs-8">
                <span id="address" />
            </div>
            <div id="statusDiv" class="col-xs-4">
                <span id="status" />
            </div>
        </div>
    </div>
</body>
</html>
