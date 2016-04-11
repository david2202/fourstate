<!DOCTYPE html>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>

<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" type="text/css" href="<c:url value='/css/bootstrap.min.css'/>"/>
    <link rel="stylesheet" type="text/css" href="<c:url value='/css/fourstate.css'/>"/>
    <script src="<c:url value='/scripts/jquery-2.1.4.js'/>"></script>
    <script src="<c:url value='/scripts/fourstate.js'/>"></script>
    <title>Customer Barcode Quality Assurance</title>

    <style>
        label{display:block}
    </style>
    <script>
        jQuery(document).ready(function ($) {
            var focusTimer = setInterval(function() {
                $("#scan").focus();
            }, 500);
            $('#scan').keydown(function (e){
                if(e.keyCode == 13) {
                    var scan=$("#scan").val();
                    var tokens = scan.split(",");

                    var barcodeString = "AT";
                    barcodeString += encode_num(tokens[0], 4);
                    barcodeString += encode_num(tokens[1], 16);
                    if (tokens.length == 3) {
                        barcodeString += "T";   // Padding
                        var rs = tokens[2].split(" ");
                        barcodeString += three_bars(rs[0]) + three_bars(rs[1])
                              + three_bars(rs[2]) + three_bars(rs[3]);
                    } else {
                        barcodeString += tokens[2]; // This is sent raw by the scanner (customer data)
                        var rs = tokens[3].split(" ");
                        barcodeString += three_bars(rs[0]) + three_bars(rs[1])
                              + three_bars(rs[2]) + three_bars(rs[3]);
                    }
                    barcodeString += "AT";
                    var inf = do_decode(barcodeString);
                    show_barcode(inf);
                    var status = inf.message;
                    var dpid = inf.dpid;

                    $("#dpid").text(dpid);
                    $("#status").text(status);
                    $("#scan").val("");
                    lookupAddress(inf.dpid,
                        function(deliveryPoint) {
                            if (inf.damaged || inf.format_type === "Unknown Format Code") {
                                $("#dpidDiv").removeClass("success failure").addClass("problem");
                                $("#statusDiv").removeClass("success failure").addClass("problem");
                            } else {
                                $("#dpidDiv").removeClass("problem failure").addClass("success");
                                $("#statusDiv").removeClass("problem failure").addClass("success");
                            }
                            $("#address").html(deliveryPoint.addressLine1 + "<br/>" + deliveryPoint.addressLine2);
                        },
                        function(jqXHR, errorType, exception) {
                            $("#dpidDiv").removeClass("success failure").addClass("problem");
                            $("#statusDiv").removeClass("success failure").addClass("problem");
                            if (jqXHR.status && jqXHR.status==404) {
                                $("#address").text("Not Found");
                            } else {
                                $("#address").text(errorType);
                            }
                        }
                    );
                }
            });
        });
    </script>
</head>

<body>
    <div class="container">
        <div class="row">
            <div class="col-xs-6">
                <label for="scan" class="control-label">Scan</label>
                <input id="scan" type="text" class="form-control input-lg" />
            </div>
        </div>
        <div class="row">
            <div class="col-xs-12">
                <script>generateBarcodeTable();</script>
            </div>
        </div>
        <div class="row address">
            <div id="addressDiv" class="col-xs-5">
                <span id="address" />
            </div>
            <div id="dpidDiv" class="col-xs-2">
                <label for="dpid" class="control-label">DPID</label>
                <span id="dpid" />
            </div>
            <div id="statusDiv" class="col-xs-5">
                <label for="status" class="control-label">Status</label>
                <span id="status" />
            </div>
        </div>
    </div>
</body>
</html>
