/**
  Servo Products Orion 1000M Post Processor
  Revision: 1.0
  Date: 2019-03-31 11:13:00
  FORKID {}
*/

description = "Orion 1000M CNC";
longDescription = "Servo Products Orion 1000M Post Processor";
vendor = "Legacy Machine Works";
vendorUrl = "www.legacymachineworks.com";
legal = "";
certificationLevel = 2;
minimumRevision = 24000;
version = 1.0;

extension = "cnc";
programNameIsInteger = true;
setCodePage("ascii");

capabilities = CAPABILITY_MILLING;
tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion

// user-defined properties
properties = {
    writeHeader: true, // write header info
    writeMachine: true, // write machine
    writeSimData: true,
    writeTools: true, // writes the tools
    showNotes: true, // specifies that operation notes should be output.
    writeComments: true, // write comments to program file
    writeMachine: false, // write machine info
    showSequenceNumbers: true, // show sequence numbers
    sequenceNumberStart: 10, // first sequence number
    sequenceNumberIncrement: 10, // increment for sequence numbers
    optionalStopTool: true, // optional stop between tools
    optionalStopOperation: false, // optional stop between operations
    maxProgramNameLength: 4, // specifies max length of program name/number
    maxSpindleSpeed: 3000, // specifies the maximum spindle speed
    useG28: false, // move X to home position at end of program
    disableCoolant: false, // disables all coolant codes
    manualToolChange: true, // specifies that the machine does not have a tool changer.
    dwellInSeconds: false // specifies dwell time in true = seconds or false = milliseconds.
};
  
// user-defined property definitions
propertyDefinitions = {
    writeHeader: {title:"Write Program Header Information", description:"If enabled, additional header information will be written to program.", group:0, type:"boolean"},
    writeMachine: {title:"Write machine", description:"Output the machine settings in the header of the code.", group:0, type:"boolean"},
    writeSimData: {title:"Write Simulation Data", description:"Outputs strarting location, stock, and tool info in CutViewer simulation format", group:0, type:"boolean"},
    writeTools: {title:"Write tool list", description:"Output a tool list in the header of the code.", group:0, type:"boolean"},
    showNotes: {title:"Show Notes", description:"Writes operation notes as comments in the outputted file.", type:"boolean"},
    writeComments: {title:"Write Comments to Program File", description:"If enabled, comments will be written to program.", group:0, type:"boolean"},
    writeMachine: {title:"Write Machine Information", description:"If enabled, additional machine information will be written to program.", group:0, type:"boolean"},
    showSequenceNumbers: {title:"Use Program Sequence Numbering", description:"Use sequence numbers for each line of outputted code.", group:1, type:"boolean"},
    sequenceNumberStart: {title:"Sequence Number Start", description:"The number at which to start the sequence numbers.", group:1, type:"integer"},
    sequenceNumberIncrement: {title:"Sequence Number Increment", description:"The amount by which the sequence number is incremented for each line.", group:1, type:"integer"},
    optionalStopTool: {title:"Optional Stop Between Tools", description:"Outputs optional stop code prior to each tool change.", type:"boolean"},
    optionalStopOperation: {title:"Optional Stop Between Operations", description:"Outputs optional stop code between all operations.", type:"boolean"},
    maxProgramNameLength: {title:"Maximum Program Name Length", description:"Sets the maximum program name length (defaults to 8).", type:"integer", range:[0, 8]},
    maxSpindleSpeed: {title:"Max Spindle Speed", description:"Defines the maximum spindle speed.", type:"integer", range:[0, 2000]},
    useG28: {title:"Use G28", description:"Move to X home position at end of program.", type:"boolean"},
    disableCoolant: {title:"Disable Coolant", description:"Disable all coolant codes.", type:"boolean"},
    manualToolChange: {title:"Manual Tool Change", description:"This machine requires manual tool changes.", type:"boolean"},
    dwellInSeconds: {title:"Dwell in seconds", description:"Set dwell time in seconds (otherwise milliseconds).", type:"boolean"},
};

var permittedCommentChars = " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,=_-:+";

var seqFormat = createFormat({prefix:"N", decimals:0, width:6, zeropad:true});

var gFormat = createFormat({prefix:"G", decimals:0});
var mFormat = createFormat({prefix:"M", decimals:0});

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, trim:false});
var feedFormat = createFormat({decimals:(unit == MM ? 1 : 2)});
var secFormat = createFormat({decimals:3, forceDecimal:false}); // seconds - range 0.000-9999.999
var msFormat = createFormat({decimals:0}); // milliseconds - range 0-9999999

var sFormat = createFormat({decimals:0}); // Speed in RPM

var tFormat = createFormat({decimals:0, width:2, zeropad:true}); // Tool ID
var hFormat = createFormat({decimals:0, width:2, zeropad:true}); // Tool Height
var dFormat = createFormat({decimals:0, width:2, zeropad:true}); // Tool Radius

// Variable Outputs
var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var zOutput = createVariable({onchange: function() {retracted = false;}, prefix: "Z"}, xyzFormat);
var feedOutput = createVariable({prefix: "F"}, feedFormat);

var sOutput = createVariable({prefix:"S"}, sFormat);

var tOutput = createVariable({prefix:"T"}, tFormat);
var hOutput = createVariable({prefix:"H"}, hFormat);
var dOutput = createVariable({prefix:"D"}, dFormat);

// Circular Output
var iOutput = createReferenceVariable({prefix:"I", force:true}, xyzFormat);
var jOutput = createReferenceVariable({prefix:"J", force:true}, xyzFormat);
var kOutput = createReferenceVariable({prefix:"K", force:true}, xyzFormat);

// Modal Groups
var gMotionModal = createModal({}, gFormat); // modal group 1 // G0-3, ...
var gPlaneModal = createModal({onchange:function() {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91
var gFeedModeModal = createModal({}, gFormat); // modal group 5 // G94-95
var gUnitModal = createModal({}, gFormat); // modal group 6 // G20-21
var gToolRadiusCompModal = createModal({}, gFormat); // modal group 7 // G40-42
var gToolLengthCompModal = createModal({}, gFormat); // modal group 8 // G43-44, 49
var gRetractModal = createModal({}, gFormat); // modal group 10 // G98-99
var gScalingModal = createModal({}, gFormat); // modal group 11 // G50-51
var gMacroModal = createModal({}, gFormat); // modal group 12 // G66-67
var gWCSModal = createModal({}, gFormat); // modal group 14 // G54-G59
var gRotationModal = createModal({}, gFormat); // modal group 16 // G68-G69

// Date & Time Formats
var dateFormat = createFormat({decimals:0, width:2, zeropad:true});
var timeFormat = createFormat({decimals:0, width:2, zeropad:true});

var singleLineCoolant = false; // specifies to output multiple coolant codes in one line rather than in separate lines
// samples:
// {id: COOLANT_THROUGH_TOOL, on: 88, off: 89}
// {id: COOLANT_THROUGH_TOOL, on: [8, 88], off: [9, 89]}
var coolants = [
  {id: COOLANT_FLOOD, on: 8},
  {id: COOLANT_MIST},
  {id: COOLANT_THROUGH_TOOL},
  {id: COOLANT_AIR},
  {id: COOLANT_AIR_THROUGH_TOOL},
  {id: COOLANT_SUCTION},
  {id: COOLANT_FLOOD_MIST},
  {id: COOLANT_FLOOD_THROUGH_TOOL},
  {id: COOLANT_OFF, off: 9}
];

// Fixed Settings
var numberOfTools = 32;
var firstFeedParameter = 0.0050;

// Collected State
var sequenceNumber = properties.sequenceNumberStart;
var pendingRadiusCompensation = -1;
var currentWorkOffset;
var optionalSection = false;
var forceSpindleSpeed = false;
var activeMovements; // do not use by default
var currentFeedId;
var maximumCircularRadiiDifference = toPreciseUnit(0.005, MM);
var retracted = false; // specifies that the tool has been retracted to the safe plane


// Get Formatted Date
function getDate() {

    var d = new Date();
    var days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    var months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

    var date = days[d.getDay()];
        date += " ";
        date += months[d.getMonth()];
        date += " ";
        date += dateFormat.format(d.getDate());

    timeFormat.format(d.getHours()) + ":" +
         timeFormat.format(d.getMinutes()) + ":" +
         timeFormat.format(d.getSeconds());

    return [date, d.getFullYear()];

}

// Get Formatted Time
function getTime() {

    var d = new Date();

    var time = timeFormat.format(d.getHours());
        time += ":";
        time += timeFormat.format(d.getHours());
        time += ":";
        time += timeFormat.format(d.getSeconds());

    return time;
}

// Get Formatted Date & Time
function getdateTime() {

    var date = getDate();
    var time = getTime();

    return date[0] + " " + time + " " + date[1];

}

// Return Requested M & G Codes
function getCode(code) {

    switch(code) {
        // G-Codes
        case "MOTION_RAPID": //G0
            return gMotionModal.format(0);
        case "MOTION_LINEAR": //G1
            return gMotionModal.format(1);
        case "MOTION_CIRCULAR_CW": //G2
            return gMotionModal.format(2);
        case "MOTION_CIRCULAR_CCW": //G3
            return gMotionModal.format(3);
        case "DWELL_TIME": //G4
            return gFormat.format(4);
        case "PLANE_XY": //G17
            return gPlaneModal.format(17);
        case "PLANE_ZX": //G18
            return gPlaneModal.format(18);
        case "PLANE_YZ": //G19
            return gPlaneModal.format(19);
        case "TOOL_RADIUS_COMP_OFF": //G40
            return gToolRadiusCompModal.format(40);
        case "TOOL_RADIUS_COMP_LEFT": //G41
            return gToolRadiusCompModal.format(41);
        case "TOOL_RADIUS_COMP_RIGHT": //G42
            return gToolRadiusCompModal.format(42);
        case "UNIT_IN": //G20
            return gUnitModal.format(20);
        case "UNIT_MM": //G21
            return gUnitModal.format(21);
        case "POSITION_ABS": //G90
            return gAbsIncModal.format(90);
        case "POSITION_INC": //G91
            return gAbsIncModal.format(91);
        case "FEED_MODE_PER_MIN": //G94
            return gFeedModeModal.format(94);
        case "FEED_MODE_PER_REV": //G95
            return gFeedModeModal.format(95);
        // M-Codes
        case "PROGRAM_STOP": //M0
            return mFormat.format(0);
        case "PROGRAM_STOP_OPTIONAL": //M1
            return mFormat.format(1);
        case "PROGRAM_END": //M2
            return mFormat.format(2);
        case "SPINDLE_START_CW": //M3
            return mFormat.format(3);
        case "SPINDLE_START_CCW": //M4
            return mFormat.format(4);
        case "SPINDLE_STOP": //M5
            return mFormat.format(5);
        case "TOOL_CHANGE": //M6
            return mFormat.format(6);
        case "COOLANT_ON": //M8
            return mFormat.format(8);
        case "COOLANT_OFF": //M9
            return mFormat.format(9);
        case "PROGRAM_END_RESET": //M30
            return mFormat.format(30);
        default:
            error(localize("Command " + code + " is not defined."));
            return 0;
    }

}

// Writes the specified block.
function writeBlock() {

    var blockNumber = seqFormat.format(sequenceNumber);
    var showSequenceNumbers = properties.showSequenceNumbers;
    var blockText = formatWords(arguments);

    if (blockText) {
        showSequenceNumbers ? writeWords(blockNumber, blockText) : writeWords(blockText);
        sequenceNumber += properties.sequenceNumberIncrement;
    }
    
}

// Format Comments
function formatComment(text) {
    //return "(" + String(text).replace(/[()]/g, "") + ")";
    return "(" + filterText(String(text).toUpperCase(), permittedCommentChars).replace(/[()]/g, "") + ")";
}

// Write Comments
function writeComment(text) {
    if (properties.writeComments) writeln(formatComment(localize(text)));
}

// Force output of XYZ on next output.
function forceXYZ() {
    xOutput.reset();
    yOutput.reset();
    zOutput.reset();
}

// Force output of ABC on next output.
function forceABC() {
    aOutput.reset();
    bOutput.reset();
    cOutput.reset();
}
  
// Force output of F on next output.
function forceFeed() {
    feedOutput.reset();
}
  
// Force output of XYZ, ABC and F on next output.
function forceXYZF() {
    forceXYZ();
    forceABC();
    forceFeed();
}

// Force output of G Motion Modals
function forceMotionModal() {
    gMotionModal.reset();
}

var gParams = new Object();

function onParameter(name, value) {
    gParams[name] = value;
}

function getParam(name) {

    var key = "operation:" + name;

    if (key in gParams) {
        return gParams[key].toFixed(3);
    }

    return "?";

}

// Get Formatted Parameter Value
function getParVal(p) {
    var result;
    result = getGlobalParameter(p) * (unit ? 1 : 1/25.4);
    return result.toFixed(3);
}

// Get Machine Config
function getMachineConfig() {

    var vendor = machineConfiguration.getVendor();
    var model = machineConfiguration.getModel();
    var description = machineConfiguration.getDescription();

    if (properties.writeMachine) {
        if (vendor || model || description) {
            if (vendor) writeComment("  " + localize("vendor") + ": " + vendor);
            if (model) writeComment("  " + localize("model") + ": " + model);
            if (description) writeComment("  " + localize("description") + ": "  + description);
        }
    } else {
        //machineConfiguration = new MachineConfiguration();
        //machineConfiguration.setModel = "Bridgeport";
        //setMachineConfiguration(machineConfiguration);
        //{model:"Bridgeport", description:"Bridgeport", vendor:"Bridgeport", maximumSpindleSpeed:2000, spindleAxis:(0,0,1)}
    }

}

// Get Simulation Data
function getSimData() {

    var lowX = getParVal("stock-lower-x");
    var highX = getParVal("stock-upper-x");
    var lowY = getParVal("stock-lower-y");
    var highY = getParVal("stock-upper-y");
    var lowZ = getParVal("stock-lower-z");
    var highZ = getParVal("stock-upper-z");

    writeln("");
    writeln("(Simulation Data)");
    writeln("(STOCK/BLOCK, " +
            Math.abs(highX - lowX) + ", " + 
            Math.abs(highY - lowY) + ", " + 
            Math.abs(highZ - lowZ) + ", " +
            -lowX +", " + -lowY + ", " + -lowZ + ")");
    writeln("(FROM/0,0," + getParVal("operation:clearanceHeight_value") + ")");

}

// Get Tool Data
function getToolData() {

    if (properties.writeTools) {

        var zRanges = {};

        if (is3D()) {

            var numberOfSections = getNumberOfSections();

            for (var i = 0; i < numberOfSections; ++i) {

                var section = getSection(i);
                var zRange = section.getGlobalZRange();
                var tool = section.getTool();

                if (zRanges[tool.number]) {
                    zRanges[tool.number].expandToRange(zRange);
                } else {
                    zRanges[tool.number] = zRange;
                }

            }

        }
    
        var tools = getToolTable();

        if (tools.getNumberOfTools() > 0) {

            writeln("");
            writeln("(Tools used)");

            for (var i = 0; i < tools.getNumberOfTools(); ++i) {

                var tool = tools.getTool(i);
                var comment = "T" + toolFormat.format(tool.number) + " " +
                    "D=" + xyzFormat.format(tool.diameter) + " " +
                    localize("CR") + "=" + xyzFormat.format(tool.cornerRadius);

                if ((tool.taperAngle > 0) && (tool.taperAngle < Math.PI)) {
                    comment += " " + localize("TAPER") + "=" + taperFormat.format(tool.taperAngle) + localize("deg");
                }

                if (zRanges[tool.number]) {
                    comment += " - " + localize("ZMIN") + "=" + xyzFormat.format(zRanges[tool.number].getMinimum());
                }

                comment += " - " + getToolTypeName(tool.type);
                writeComment(comment);

            }

        }

    }

}

// Built-In Functions
function onOpen() {

    var writeHeader = properties.writeHeader;
    var writeMachine = properties.writeMachine;
    var maxProgramNameLength = properties.maxProgramNameLength;

    if (properties.useRadius) {
        maximumCircularSweep = toRad(90); // avoid potential center calculation errors for CNC
    }

    // Program Name
    if (!programName) {
        error(localize("Program name has not been specified."));
        return;
    } else {
        if (programName.length > maxProgramNameLength) {
            error(localize("Program name is too long. Must be [" + maxProgramNameLength + "] characters or less."));
            return;
        }
    }

    // Program Name
    if (programName) {
        if (programName.length <= maxProgramNameLength) {
            if (writeHeader) {
                writeComment(programName + "." + extension);
            }
        } else {
            error(localize("Program name is too long. Must be [" + maxProgramNameLength + "] characters or less."));
            return;
        }
    } else {
        error(localize("Program name has not been specified."));
        return;
    }
    
    // Program Comment
    if (programComment && writeHeader) {
        writeComment(programComment);
    }

    // Get machine configuration
    var vendor = machineConfiguration.getVendor();
    var model = machineConfiguration.getModel();
    var description = machineConfiguration.getDescription();

    if (writeMachine && (vendor || model || description)) {
        writeComment("Machine");
        if (vendor) {
            writeComment("  vendor: " + vendor);
        }
        if (model) {
            writeComment("  model: " + model);
        }
        if (description) {
            writeComment("  description: " + description);
        }
    }

    // TODO: this section needs logic

    // Set Program Units IN || MM
    writeBlock((unit == IN) ? getCode("UNIT_IN") : getCode("UNIT_MM"), (unit == IN) ? formatComment("SET UNIT_IN") : formatComment("SET UNIT_MM"));

    // Setup Program Coordinates
    writeBlock(getCode("PLANE_ZX"), formatComment("SET PLANE_ZX"));

    // Setup Program Position Mode
    writeBlock(getCode("POSITION_ABS"), formatComment("SET POSITION_ABS"));

    // Setup Program Feed Mode
    writeBlock(getCode("FEED_MODE_PER_REV"), formatComment("SET FEED_MODE_PER_REV"));

}


function onSection() {

    retracted = false;

    // Section: Comment
    if (hasParameter("operation-comment")) {
        var comment = getParameter("operation-comment");
        if (comment) {
            writeComment(comment);
        }
    }

    var insertToolCall = isFirstSection() 
        || currentSection.getForceToolChange && currentSection.getForceToolChange() 
        || (tool.number != getPreviousSection().getTool().number); // tool change

    var newWorkOffset = isFirstSection() 
        || (getPreviousSection().workOffset != currentSection.workOffset); // work offset changes

    var newWorkPlane = isFirstSection() 
        || !isSameDirection(getPreviousSection().getGlobalFinalToolAxis(), currentSection.getGlobalInitialToolAxis()) 
        || (currentSection.isOptimizedForMachine() && getPreviousSection().isOptimizedForMachine() 
        && Vector.diff(getPreviousSection().getFinalToolAxisABC(), currentSection.getInitialToolAxisABC()).length > 1e-4) 
        || (!machineConfiguration.isMultiAxisConfiguration() && currentSection.isMultiAxis()) 
        || (!getPreviousSection().isMultiAxis() && currentSection.isMultiAxis() 
        || getPreviousSection().isMultiAxis() && !currentSection.isMultiAxis()); // force newWorkPlane between indexing and simultaneous operations
    
    // Check for Tool Change, WCS Change or Work Plane Change
    if (insertToolCall || newWorkOffset || newWorkPlane) {

        // stop spindle before retract during tool change
        if (insertToolCall && !isFirstSection()) {
            onCommand(COMMAND_STOP_SPINDLE);
        }

        // retract to safe plane
        writeRetract(Z);
        zOutput.reset();

    }

    // Section: Tool Change
    if (insertToolCall) {

        forceWorkPlane();
        
        setCoolant(COOLANT_OFF);
      
        if (!isFirstSection() && properties.optionalStop) {
            warning(localize("Optional stop not supported. Set 'Optional Stop' to 'No' in 'Post Process' dialog for setup"))
            error(localize("Optional Stop (M1) not supported"));
            return;
            onCommand(COMMAND_OPTIONAL_STOP);
        }
    
        if (tool.number > numberOfTools) {
            warning(localize("Tool number exceeds maximum value."));
        }
    
        writeln("");

        switch (tool.getType()) {
            case TOOL_DRILL_SPOT:
            case TOOL_DRILL:
                writeln("(TOOL/DRILL, " + getParam("tool_diameter") + ", " +
                    getParam("tool_tipAngle") + ", " + 
                    getParam("tool_fluteLength") + ")");      
                break;
            case TOOL_DRILL_CENTER:
                writeln("(TOOL/CDRILL, " + getParam("tool_diameter") + ", " +
                    getParam("tool_tipAngle") + ", " +
                    getParam("tool_tipLength") + ", " + 
                    getParam("tool_tipDiameter") + ", " +
                    getParam("tool_taperAngle") + ", " + 
                    getParam("tool_fluteLength") + ")");
                break;
            case TOOL_MILLING_END_BALL:
            case TOOL_MILLING_END_FLAT:
            case TOOL_MILLING_END_BULLNOSE:
            case TOOL_MILLING_FACE:
            case TOOL_MILLING_SLOT:
            case TOOL_MILLING_RADIUS:
            case TOOL_TAP_RIGHT_HAND:
            case TOOL_TAP_LEFT_HAND:
            case TOOL_REAMER:
                writeln("(TOOL/MILL, " + getParam("tool_diameter") + ", " +
                    getParam("tool_cornerRadius") + ", " +
                    getParam("tool_fluteLength") + ", " + 
                    getParam("tool_taperAngle") + ")");                           
                break;
            case TOOL_MILLING_CHAMFER:
                writeln("(TOOL/CHAMFER, " + getParam("tool_diameter") + ", " +
                    getParam("tool_taperAngle") + ", " +
                    getParam("tool_shoulderLength") + ", " +
                    getParam("tool_fluteLength") + ")"  );
                break;
            case TOOL_COUNTER_SINK:
                writeln("(TOOL/CHAMFER, " + getParam("tool_diameter") + ", " +
                    getParam("tool_tipAngle") + ", " +
                    getParam("tool_shoulderLength") + ", " +
                    getParam("tool_fluteLength") + ")"  );
                break;
            default:
                writeln("(CAN'T SIMULATE TOOL TYPE [" + tool.getType() + "])")
        };

    }
    
    // Section: Feed Mode
    if (currentSection.feedMode == FEED_PER_REVOLUTION) {
        feedFormat.setScale(tool.spindleRPM);
        feedModal = createModal({prefix:" F"}, feedFormat);
    } else {
        feedFormat.setScale(1);
        feedModal = createModal({prefix:" F"}, feedFormat);
    }

    // Section: Set Spindle Speed
    onSpindleSpeed(tool.spindleRPM);

}


function onComment(comment) {
    writeComment(comment);
}

// Output Dwell Time
function onDwell(time) {

    if (properties.dwellInSeconds) {

        var seconds = time;

        if (seconds > 9999.999) {
            warning(localize("Dwelling time is out of range (0-9999.999)."));
        } else {
            seconds = clamp(0.001, seconds, 99999.999);
            writeBlock(gFormat.format(4), "X" + secFormat.format(seconds));
        }

    } else {

        var milliseconds = time;

        if (milliseconds > 9999999) {
            warning(localize("Dwelling time is out of range (0-9999999)."));
        } else {
            milliseconds = clamp(1, seconds, 99999999);
            writeBlock(gFormat.format(4), "P" + msFormat.format(milliseconds));
        }

    }

}

// Output Spindle Speed
function onSpindleSpeed(spindleSpeed) {
    writeBlock(sOutput.format(spindleSpeed));
}


function onRadiusCompensation() {
    pendingRadiusCompensation = radiusCompensation;
}


function onToolCompensation(compensation) {
    // code here
}


function onRapid(_x, _y, _z) {

    var x = xOutput.format(_x);
    var y = xOutput.format(_y);
    var z = zOutput.format(_z);

    if (x || y || z) {

        if (pendingRadiusCompensation >= 0) {
            error(localize("Radius compensation mode cannot be changed at rapid traversal."));
            return;
        }

        writeBlock(getCode("MOTION_RAPID"), x, y, z);
        forceFeed();

    }

}


function onLinear(_x, _y, _z, feed) {

    // force move when radius compensation changes
    if (pendingRadiusCompensation >= 0) {
        xOutput.reset();
        yOutput.reset();
    }

    var x = xOutput.format(_x);
    var y = xOutput.format(_y);
    var z = zOutput.format(_z);
    var f = feedOutput.format(feed);
    
    if (x || y || z) {

        if (pendingRadiusCompensation >= 0) {

            pendingRadiusCompensation = -1;
            var d = tool.diameterOffset;

            if (d > numberOfTools) warning(localize("The diameter offset exceeds the maximum value."));

            writeBlock(getCode("PLANE_XY"));

            switch (radiusCompensation) {
                case RADIUS_COMPENSATION_LEFT:
                    dOutput.reset();
                    writeBlock(getCode("MOTION_LINEAR"), getCode("TOOL_RADIUS_COMP_LEFT"), x, y, z, dOutput.format(d), f);
                    break;
                case RADIUS_COMPENSATION_RIGHT:
                    dOutput.reset();
                    writeBlock(getCode("MOTION_LINEAR"), getCode("TOOL_RADIUS_COMP_RIGHT"), x, y, z, dOutput.format(d), f);
                    break;
                default:
                    writeBlock(getCode("MOTION_LINEAR"), getCode("TOOL_RADIUS_COMP_OFF"), x, y, z, dOutput.format(d), f);
            }
        } else {
            writeBlock(getCode("MOTION_LINEAR"), x, y, z, f);
        }

    } else if (f) {
        if (getNextRecord().isMotion()) { // try not to output feed without motion
            forceFeed(); // force feed on next line
        } else {
            writeBlock(getCode("FEED_MODE_PER_MIN"), getCode("MOTION_LINEAR"), f);
        }
    }

}


function onCircular(clockwise, cx, cy, cz, _x, _y, _z, feed) {

    if (pendingRadiusCompensation >= 0) {
        error(localize("Radius compensation cannot be activated/deactivated for a circular move."));
        return;
    }

    var start = getCurrentPosition();

    var x = xOutput.format(_x);
    var y = xOutput.format(_y);
    var z = zOutput.format(_z);
    var f = feedOutput.format(feed);

    var i = iOutput.format(cx - start.x, 0);
    var j = jOutput.format(cy - start.y, 0);
    var k = kOutput.format(cz - start.z, 0);

    if (isFullCircle()) {

        if (isHelical()) {
            linearize(tolerance);
            return;
        }

        switch (getCircularPlane()) {
            case PLANE_XY:
                writeBlock(getCode("PLANE_XY"), getCode(clockwise ? "MOTION_CIRCULAR_CW" : "MOTION_CIRCULAR_CCW"), x, i, j, f);
                break;
            case PLANE_ZX:
                writeBlock(getCode("PLANE_ZX"), getCode(clockwise ? "MOTION_CIRCULAR_CW" : "MOTION_CIRCULAR_CCW"), z, i, k, f);
                break;
            case PLANE_YZ:
                writeBlock(getCode("PLANE_YZ"), getCode(clockwise ? "MOTION_CIRCULAR_CW" : "MOTION_CIRCULAR_CCW"), y, j, k, f);
                break;
            default:
                linearize(tolerance);
        }

    } else {

        switch (getCircularPlane()) {
            case PLANE_XY:
                writeBlock(getCode("PLANE_XY"), getCode(clockwise ? "MOTION_CIRCULAR_CW" : "MOTION_CIRCULAR_CCW"), x, y, z, i, j, f);
                break;
            case PLANE_ZX:
                writeBlock(getCode("PLANE_ZX"), getCode(clockwise ? "MOTION_CIRCULAR_CW" : "MOTION_CIRCULAR_CCW"), x, y, z, i, k, f);
                break;
            case PLANE_YZ:
                writeBlock(getCode("PLANE_YZ"), getCode(clockwise ? "MOTION_CIRCULAR_CW" : "MOTION_CIRCULAR_CCW"), x, y, z, j, k, f);
                break;
            default:
                linearize(tolerance);
        }

    }

}

function setCoolant(coolant) {

    var coolantCodes = getCoolantCodes(coolant);

    if (Array.isArray(coolantCodes)) {

        for (var c in coolantCodes) {
            writeBlock(coolantCodes[c]);
        }

        return undefined;

    }

    return coolantCodes;

}
  
function getCoolantCodes(coolant) {

    if (!coolants) {
        error(localize("Coolants have not been defined."));
    }

    if (!coolantOff) { // use the default coolant off command when an 'off' value is not specified for the previous coolant mode
        coolantOff = coolants.off;
    }

    if (isProbeOperation()) { // avoid coolant output for probing
        coolant = COOLANT_OFF;
    }

    if (coolant == currentCoolantMode) {
        return undefined; // coolant is already active
    }

    var multipleCoolantBlocks = new Array(); // create a formatted array to be passed into the outputted line
    if ((coolant != COOLANT_OFF) && (currentCoolantMode != COOLANT_OFF)) {
        multipleCoolantBlocks.push(mFormat.format(coolantOff));
    }

    var m;

    if (coolant == COOLANT_OFF) {
        m = coolantOff;
        coolantOff = coolants.off;
    }

    switch (coolant) {
        case COOLANT_FLOOD:
            if (!coolants.flood) {
                break;
            }
            m = coolants.flood.on;
            coolantOff = coolants.flood.off;
            break;
        case COOLANT_THROUGH_TOOL:
            if (!coolants.throughTool) {
                break;
            }
            m = coolants.throughTool.on;
            coolantOff = coolants.throughTool.off;
            break;
        case COOLANT_AIR:
            if (!coolants.air) {
                break;
            }
            m = coolants.air.on;
            coolantOff = coolants.air.off;
            break;
        case COOLANT_AIR_THROUGH_TOOL:
            if (!coolants.airThroughTool) {
                break;
            }
            m = coolants.airThroughTool.on;
            coolantOff = coolants.airThroughTool.off;
            break;
        case COOLANT_FLOOD_MIST:
            if (!coolants.floodMist) {
                break;
            }
            m = coolants.floodMist.on;
            coolantOff = coolants.floodMist.off;
            break;
        case COOLANT_MIST:
            if (!coolants.mist) {
                break;
            }
            m = coolants.mist.on;
            coolantOff = coolants.mist.off;
            break;
        case COOLANT_SUCTION:
            if (!coolants.suction) {
                break;
            }
            m = coolants.suction.on;
            coolantOff = coolants.suction.off;
            break;
        case COOLANT_FLOOD_THROUGH_TOOL:
            if (!coolants.floodThroughTool) {
                break;
            }
            m = coolants.floodThroughTool.on;
            coolantOff = coolants.floodThroughTool.off;
            break;
    }

    if (!m) {
        onUnsupportedCoolant(coolant);
        m = 9;
    }

    if (m) {

        if (Array.isArray(m)) {
            for (var i in m) {
                multipleCoolantBlocks.push(mFormat.format(m[i]));
            }
        } else {
            multipleCoolantBlocks.push(mFormat.format(m));
        }

        currentCoolantMode = coolant;

        return multipleCoolantBlocks; // return the single formatted coolant value

    }

    return undefined;

}
  
var mapCommand = {
COMMAND_STOP:0,
COMMAND_OPTIONAL_STOP:1,
COMMAND_END:2,
COMMAND_SPINDLE_CLOCKWISE:3,
COMMAND_SPINDLE_COUNTERCLOCKWISE:4,
COMMAND_STOP_SPINDLE:5,
COMMAND_ORIENTATE_SPINDLE:19,
COMMAND_LOAD_TOOL:6
};

function onCommand(command) {
    switch (command) {
        case COMMAND_COOLANT_ON:
            writeBlock(getCode("COOLANT_ON"), formatComment("COOLANT ON"));
            break;
        case COMMAND_COOLANT_OFF:
            writeBlock(getCode("COOLANT_OFF"), formatComment("COOLANT OFF"));
            break;
        case COMMAND_ACTIVATE_SPEED_FEED_SYNCHRONIZATION:
            break;
        case COMMAND_DEACTIVATE_SPEED_FEED_SYNCHRONIZATION:
            break;
        case COMMAND_STOP:
            writeBlock(getCode("PROGRAM_STOP"), formatComment("PROGRAM STOP"));
            break;
        case COMMAND_OPTIONAL_STOP:
            writeBlock(getCode("PROGRAM_STOP_OPTIONAL"), formatComment("PROGRAM STOP OPTIONAL"));
            break;
        case COMMAND_END:
            writeBlock(getCode("PROGRAM_STOP_RESTART"), formatComment("PROGRAM END"));
            break;
        case COMMAND_SPINDLE_CLOCKWISE:
            writeBlock(getCode("SPINDLE_START_CW"), formatComment("SPINDLE START CW"));
            break;
        case COMMAND_SPINDLE_COUNTERCLOCKWISE:
            writeBlock(getCode("SPINDLE_START_CCW"), formatComment("SPINDLE START CCW"));
            break;
        case COMMAND_START_SPINDLE:
            onCommand(tool.isClockwise() ? COMMAND_SPINDLE_CLOCKWISE : COMMAND_SPINDLE_COUNTERCLOCKWISE);
            break;
        case COMMAND_STOP_SPINDLE:
            writeBlock(getCode("SPINDLE_STOP"), formatComment("SPINDLE STOP"));
            break;
        default:
            //onUnsupportedCommand(command);
            error(localize("COMMAND not found!"));
        }
}


function onCycle() {

}


function getCommonCycle(x, y, z, r) {
    forceXZ(); // force xz on first drill hole of any cycle
    return [
        xOutput.format(x),
        zOutput.format(z),
        rOutput.format(r)
    ];
}


function onCyclePoint() {

}


function onCycleEnd() {
    if (!cycleExpanded) {
        switch (cycleType) {
            case "thread-turning":
                forceFeed();
                xOutput.reset();
                zOutput.reset();
                g92ROutput.reset();
                break;
            default:
                writeBlock(gCycleModal.format(80));
        }
    }
}


function onSectionEnd() {
    forceXZF();
}


function onClose() {
    writeComment("PROGRAM CLOSE");
    onCommand(COMMAND_COOLANT_OFF);
    onCommand(COMMAND_STOP_SPINDLE);
    onCommand(COMMAND_END);
}

function onTerminate() {

}