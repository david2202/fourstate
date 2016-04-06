<!DOCTYPE html>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>

<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" type="text/css" href="<c:url value='/css/bootstrap.min.css'/>"/>
    <link rel="stylesheet" type="text/css" href="<c:url value='/css/fourstate.css'/>"/>
    <script src="<c:url value='/scripts/jquery-2.1.4.js'/>"></script>
    <script src="<c:url value='/scripts/fourstate.js'/>"></script>

    <title>Barcode recognition with JavaScript</title>

    <script>
        jQuery(document).ready(function ($) {
            $("#scan").focus();
            $('#scan').keydown(function (e){
                if(e.keyCode == 13) {
                    var dpid=$("#scan").val();
                    lookupAddress(dpid, function(deliveryPoint) {
                        $("#dpid").text(dpid);
                        $("#address").html(deliveryPoint.addressLine1 + "<br/>" + deliveryPoint.addressLine2);
                        $("#scan").val("");
                    });
                }
            });
        });
    </script>
</head>

<body>
    <div class="container">
        <div class="row">
            <div class="col-xs-12">
                <label for="scan" class="control-label">Scan</label>
                <input id="scan" type="text" class="form-control input-lg" />
            </div>
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
