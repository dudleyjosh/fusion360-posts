/**
  Bridgeport EZ-Path Conversational & G-Code Post Processor
  Revision: 1.0
  Date: 2018-07-05 11:13:00
  FORKID {}
*/

description = "Bridgeport EZ-Path Conversational & G-Code Post Processor";
longDescription = "";
vendor = "Legacy Machine";
vendorUrl = "";
legal = "";
certificationLevel = 2;
minimumRevision = 24000;
version = 1.0;

//extension = "pgm"; // Posts Bridgeport EZ-Path Conversational Code
extension = "txt"; // Posts G-Code
programNameIsInteger = false;
setCodePage("ascii");

capabilities = CAPABILITY_TURNING;
tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.01, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = true;
allowedCircularPlanes = (1 << PLANE_ZX); // allow only the ZX plane

//machineConfiguration = new MachineConfiguration();
//machineConfiguration.setModel = "EZ-Path SD";
//setMachineConfiguration(machineConfiguration);
//{model:"EZ-Path SD", description:"Bridgeport-Romi EZ-Path SD", vendor:"Bridgeport", maximumSpindleSpeed:2000, spindleAxis:(0,0,1)}

// user-defined properties
properties = {
    writeHeader: true, // write header info
    showNotes: false, // specifies that operation notes should be output.
    writeComments: false, // write comments to program file
    writeMachine: true, // write machine info
    showSequenceNumbers: true, // show sequence numbers
    sequenceNumberStart: 10, // first sequence number
    sequenceNumberIncrement: 10, // increment for sequence numbers
    optionalStopTool: true, // optional stop between tools
    optionalStopOperation: false, // optional stop between operations
    maxProgramNameLength: 8, // specifies max length of program name/number
    maxSpindleSpeed: 3000, // specifies the maximum spindle speed
    useG28: false, // move X to home position at end of program
    disableCoolant: false, // disables all coolant codes
    manualToolChange: true, // specifies that the machine does not have a tool changer.
    useRadius: true, // specifies that arcs should be output using the radius (R word) instead of the I, J, and K words.
    reverseCircular: false // swap CW for CCW and CCW for CW
};
  
// user-defined property definitions
propertyDefinitions = {
    writeHeader: {title:"Write Program Header Information", description:"If enabled, additional header information will be written to program.", group:0, type:"boolean"},
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
    useRadius: {title:"Use Arc Radius", description:"If yes is selected, arcs are output using radius values rather than IJK.", type:"boolean"},
    reverseCircular: {title:"Swap CW & CCW", description:"Swap circular interpolation movements CW & CCW.", type:"boolean"},
};


var conversational = (extension === "pgm") ? true : false;

var permittedCommentChars = " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,=_-:+";

// (Seqence Number Format for EZ-Path Conversation *.pgm) : (Seqence Number Format for EZ-Path G-Code *.txt)
var seqFormat = (conversational) ? createFormat({decimals:0, width:4, zeropad:true}) : createFormat({prefix:"N", decimals:0, width:6, zeropad:true});

var toolIdFormat = (conversational) ? createFormat({prefix:"I", decimals:0}) : createFormat({prefix:"T", decimals:0, width:2, zeropad:true});
var toolNumberFormat = createFormat({prefix:"T", decimals:0, width:2, zeropad:true});
var toolOffsetFormat = createFormat({decimals:0, width:2, zeropad:true});

var toolIdModal = createModal({}, toolIdFormat);
var toolNumberModal = createModal({}, toolNumberFormat);
var toolOffsetModal = createModal({}, toolOffsetFormat);

var gFormat = createFormat({prefix:"G", decimals:0});
var mFormat = createFormat({prefix:"M", decimals:0});

var gMotionModal = createModal({}, gFormat); // modal group 1 // G0-3, G33-34...
var gDwellModal = createModal({}, gFormat); // G4
var gPlaneModal = createModal({onchange:function() {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19
var gSpindleModeModal = createModal({}, gFormat); // modal group 5 // G36-38
var gToolRadiusCompModal = createModal({}, gFormat); // G40-42
var gUnitModal = createModal({}, gFormat); // modal group 6 // G70-71
var gCycleModal = createModal({}, gFormat); // modal group 9 // G81-G89
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91
var gFeedModeModal = createModal({}, gFormat); // modal group 5 // G94-95
var gRetractModal = createModal({}, gFormat); // modal group 10 // G98-99

var xFormat = createFormat({prefix:"X", decimals:(unit == MM ? 3 : 4), forceDecimal:true, trim:false, scale:2}); // diameter mode
var zFormat = createFormat({prefix:"Z", decimals:(unit == MM ? 3 : 4), forceDecimal:true, trim:false});
var rFormat = createFormat({prefix:"R", decimals:(unit == MM ? 3 : 4), forceDecimal:true, trim:false}); // radius
var feedFormat = createFormat({prefix:"F", decimals:(unit == MM ? 3 : 4), forceDecimal:true, trim:false});
var pitchFormat = createFormat({prefix:"F", decimals:(unit == MM ? 3 : 4), forceDecimal:true, trim:false});
var rpmFormat = createFormat({prefix:"S", decimals:0});
var cssFormat = createFormat({prefix:((conversational) ? "C" : "S"), decimals:((conversational) ? 2 : 0), forceDecimal:((conversational) ? true : false), trim:false});

// Date & Time Formats
var dateFormat = createFormat({decimals:0, width:2, zeropad:true});
var timeFormat = createFormat({decimals:0, width:2, zeropad:true});

var xOutput = createVariable({force:true}, xFormat);
var zOutput = createVariable({force:true}, zFormat);
var rOutput = createVariable({force:true}, rFormat);
var feedOutput = createVariable({force:true}, feedFormat);
var pitchOutput = createVariable({force:true}, pitchFormat);
var rpmOutput = createVariable({force:true}, rpmFormat);
var cssOutput = createVariable({force:true}, cssFormat);

// circular output
var spatialFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, trim:false});
var iOutput = createReferenceVariable({prefix:"I", force:true}, spatialFormat);
var kOutput = createReferenceVariable({prefix:"K", force:true}, spatialFormat);


// fixed settings
var firstFeedParameter = 0.0050;
var gotSecondarySpindle = false;
var gotDoorControl = false;
var gotTailStock = false;
var gotBarFeeder = false;

// collected state
var sequenceNumber = properties.sequenceNumberStart;
var pendingRadiusCompensation = -1;
var currentWorkOffset;
var optionalSection = false;
var forceSpindleSpeed = false;
var activeMovements; // do not use by default
var currentFeedId;
var maximumCircularRadiiDifference = toPreciseUnit(0.005, MM);


// Get EZ-Path formatted Date
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

// Get EZ-Path formatted Time
function getTime() {

    var d = new Date();

    var time = timeFormat.format(d.getHours());
        time += ":";
        time += timeFormat.format(d.getHours());
        time += ":";
        time += timeFormat.format(d.getSeconds());

    return time;
}

// Get EZ-Path Date & Time
function getEzPathDateTime() {

    var date = getDate();
    var time = getTime();

    return date[0] + " " + time + " " + date[1];

}

// Get EZ-Path Header
function getEzPathHeader() {

    var blockNum = seqFormat.format(0);
    var control = "EZPATH|SX 1";
    var mode = (unit == IN) ? "MODE|INCH" : "MODE|MM";
    var dateTime = getEzPathDateTime();

    var ezPathHeader = blockNum;
        ezPathHeader += " ";
        ezPathHeader += control;
        ezPathHeader += " ";
        ezPathHeader += mode;
        ezPathHeader += " ";
        ezPathHeader += dateTime;

    return ezPathHeader;

}

// Return requested M & G Codes
function getCode(code) {

    var conversational = (extension == "pgm") ? true : false;

    switch(code) {
        // M-Codes
        case "PROGRAM_STOP": //M0
            return (conversational) ? "AUXFUN " + mFormat.format(0) : mFormat.format(0);
        case "PROGRAM_STOP_OPTIONAL": //M1
            return (conversational) ? "AUXFUN " + mFormat.format(1) : mFormat.format(1);
        case "PROGRAM_STOP_RESTART": //M2
            return (conversational) ? "AUXFUN " + mFormat.format(2) : mFormat.format(2);
        case "SPINDLE_START_CW": //M3
            return mFormat.format(3);
        case "SPINDLE_START_CCW": //M4
            return mFormat.format(4);
        case "SPINDLE_STOP": //M5
            return (conversational) ? "AUXFUN " + mFormat.format(5) : mFormat.format(5);
        case "TOOL_CHANGE": //M6
            return (conversational) ? "TLCHG" : mFormat.format(6);
        case "COOLANT_ON": //M8
            return (conversational) ? "AUXFUN " + mFormat.format(8) : mFormat.format(8);
        case "COOLANT_OFF": //M9
            return (conversational) ? "AUXFUN " + mFormat.format(9) : mFormat.format(9);
        case "GEAR_1": //M11
            return (conversational) ? "G1" : mFormat.format(11);
        case "GEAR_2": //M12
            return (conversational) ? "G2" : mFormat.format(12);
        case "GEAR_3": //M13
            return (conversational) ? "G3" : mFormat.format(13);
        case "PROGRAM_RESET": //M30
            return mFormat.format(30);
        // G-Codes
        case "MOTION_RAPID": //G0
            return (conversational) ? "RAPID ABS" : "G90 " + gMotionModal.format(0);
        case "MOTION_LINEAR": //G1
            return (conversational) ? "LINE ABS" : "G90 " + gMotionModal.format(1);
        case "MOTION_CIRCULAR_CW": //G2
            if (conversational) {
                return (properties.useRadius) ? "ARC|RADIUS ABS CW" : "ARC|CNTRPT ABS CW";
            } else {
                return "G90 " + gMotionModal.format(2);
            }
        case "MOTION_CIRCULAR_CCW": //G3
            if (conversational) {
                return (properties.useRadius) ? "ARC|RADIUS ABS CCW" : "ARC|CNTRPT ABS CCW";
            } else {
                return "G90 " + gMotionModal.format(3);
            }
        case "DWELL_TIME": //G4
            return (conversational) ? "DWELL" : gDwellModal.format(4);
        case "PLANE_XY": //G17
            return gPlaneModal.format(17);
        case "PLANE_ZX": //G18
            return gPlaneModal.format(18);
        case "PLANE_YZ": //G19
            return gPlaneModal.format(19);
        case "MOTION_THREAD_START": //G33
            return gMotionModal.format(33);
        case "MOTION_THREAD_STOP": //G34
            return gMotionModal.format(34);
        case "SPINDLE_RPM": //G36
            return (conversational) ? "SETRPM" : gSpindleModeModal.format(36);
        case "SPINDLE_CSS_SFM": //G37
            return (conversational) ? "SETCSS" : gSpindleModeModal.format(37);
        case "SPINDLE_RPM_MAX": //G38
            return gSpindleModeModal.format(38);
        case "TOOL_RADIUS_COMP_OFF": //G40
            return gToolRadiusCompModal.format(40);
        case "TOOL_RADIUS_COMP_LEFT": //G41
            return gToolRadiusCompModal.format(41);
        case "TOOL_RADIUS_COMP_RIGHT": //G42
            return gToolRadiusCompModal.format(42);
        case "UNIT_IN": //G70
            return gUnitModal.format(70);
        case "UNIT_MM": //G71
            return gUnitModal.format(71);
        case "POSITION_ABS": //G90
            return gAbsIncModal.format(90);
        case "POSITION_INC": //G91
            return gAbsIncModal.format(91);
        case "FEED_MODE_PER_MIN": //G94
            return gFeedModeModal.format(94);
        case "FEED_MODE_PER_REV": //G95
            return gFeedModeModal.format(95);
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
    return "'" + filterText(text, permittedCommentChars).replace(/[\(\)]/g, "");
}

// Write Comments
function writeComment(text) {
    if (properties.writeComments) writeln(formatComment(localize(text)));
}

// Force output of X and Z on next output.
function forceXZ() {
    xOutput.reset();
    zOutput.reset();
}
  
// Force output of F on next output.
function forceFeed() {
    feedOutput.reset();
}
  
// Force output of X, Z, and F on next output.
function forceXZF() {
    forceXZ();
    forceFeed();
}

// Force output of G Motion Modals
function forceMotionModal() {
    gMotionModal.reset();
}

// Force output of Tool Changes
function forceToolChange() {
    toolIdModal.reset();
    toolNumberModal.reset();
    toolOffsetModal.reset();
}

// Tooling Data
function ToolingData(_tool) {
    
    switch (_tool.turret) {
        // QCTP X-
        case 1:
          this.tooling = QCTP;
          this.toolPost = FRONT;
          break;
        // QCTP X+
        case 2:
          this.tooling = QCTP;
          this.toolPost = REAR;
          break;
        default:
          error(localize("Turret number must be in the range of 0-4."));
          break;
    }

    this.number = _tool.number;
    this.comment = _tool.comment;
    this.toolLength = _tool.bodyLength;
    // HSMWorks returns 0 in tool.bodyLength
    if ((tool.bodyLength == 0) && hasParameter("operation:tool_bodyLength")) {
      this.toolLength = getParameter("operation:tool_bodyLength");
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

    if (conversational) {
        writeln(getEzPathHeader());
    } else {

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

}


function onSection() {

    // Section: Comment
    if (!conversational) {
        if (hasParameter("operation-comment")) {
            var comment = getParameter("operation-comment");
            if (comment) {
                writeComment(comment);
            }
        }
    }

    // Section: Tool Change
    if (properties.manualToolChange) {

        if (conversational) {
            writeBlock(getCode("TOOL_CHANGE"), toolIdModal.format(tool.number), toolNumberModal.format(tool.number), toolOffsetModal.format(compensationOffset));
        } else {
            writeBlock(toolIdModal.format(tool.number) + "/" + toolOffsetModal.format(compensationOffset), getCode("TOOL_CHANGE"));
        }
        
        forceToolChange();

    } else {
        // TODO: Logic goes here
    }

    /*
    var forceToolAndRetract = optionalSection && !currentSection.isOptional();
    optionalSection = currentSection.isOptional();

	if (tool.manualToolChange) {

        var x, z, lastTool;

        if (!isFirstSection()) {
            x = xOutput.format(getPreviousSection().getInitialPosition().x + 2);
		    z = zOutput.format(getPreviousSection().getInitialPosition().z + 2);
		    lastTool = getPreviousSection().getTool();
        }
					
		if (lastTool.number != tool.number) {
			writeBlock(gMotionModal.format(0), x, z);
        }

        writeBlock(toolIdModal.format(tool.number) + "/" + toolOffsetModal.format(compensationOffset) + " " + getCode("TOOL_CHANGE"));
        
        if (tool.comment) {
            writeComment(tool.comment);
        }
        
    }

    var insertToolCall = 
        isFirstSection() ||
        forceToolAndRetract || 
        (currentSection.getForceToolChange && currentSection.getForceToolChange()) || 
        (tool.number != getPreviousSection().getTool().number);

    if (insertToolCall) {
        writeBlock(toolIdModal.format(tool.number) + "/" + toolOffsetModal.format(compensationOffset) + " " + getCode("TOOL_CHANGE"));
    }
    */
    
    // Section: Feed Mode
    if (currentSection.feedMode == FEED_PER_REVOLUTION) {
        feedFormat.setScale(tool.spindleRPM);
        feedModal = createModal({prefix:" F"}, feedFormat);
    } else {
        feedFormat.setScale(1);
        feedModal = createModal({prefix:" F"}, feedFormat);
    }

    // Section: Speed & Gear Selection
    onSpindleSpeed(tool.spindleRPM);

}


function onComment(comment) {
    writeComment(comment);
}


function onDwell() {

}


function onRadiusCompensation() {
    pendingRadiusCompensation = radiusCompensation;
}


function onToolCompensation(compensation) {
    // code here
}


function onSpindleSpeed(spindleSpeed) {

    // Select Gear 2
    if (!conversational) writeBlock(getCode("GEAR_2"), formatComment("GEAR 2 SELECTED"));

    // Check for Constant Surface Speed
    if (currentSection.getTool().getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
    
        var maxSpindleSpeed = (tool.maximumSpindleSpeed > 0) ? Math.min(tool.maximumSpindleSpeed, properties.maxSpindleSpeed) : properties.maxSpindleSpeed;
        var css = tool.surfaceSpeed * ((unit == IN) ? 1/12.0 : 1/1000.0);
        
        if (conversational) {
            writeBlock(getCode("SPINDLE_CSS_SFM"), getCode("GEAR_2"), cssOutput.format(css), rpmOutput.format(maxSpindleSpeed));
        } else {
            writeBlock(getCode("SPINDLE_RPM_MAX"), rpmOutput.format(maxSpindleSpeed), formatComment("SET MAX RPM"));
            writeBlock(getCode("SPINDLE_CSS_SFM"), cssOutput.format(css), formatComment("SET SPINDLE CSS_SFM"));
        }
            
    } else {
        if (conversational) {
            writeBlock(getCode("SPINDLE_RPM"), getCode("GEAR_2"), rpmOutput.format(Math.abs(spindleSpeed)));
        } else {
            writeBlock(getCode("SPINDLE_RPM"), rpmOutput.format(Math.abs(spindleSpeed)), getCode("SPINDLE_START_CW"));
        }
    }

    // Spindle Start Command
    if (!conversational) {
        tool.isClockwise() ? writeBlock(getCode("SPINDLE_START_CW"), formatComment("SPINDLE START CW")) : writeBlock(getCode("SPINDLE_START_CCW"), formatComment("SPINDLE START CCW"));
    }

    //Check to see if a gear change is necessary for earlier EZ-Path machines with physical gearbox
    /*
    var requestedGear = gearCheck(maxSpindleSpeed);

    if ((requestedGear != selectedGear) || isFirstSection()) {
        writeBlock(mFormat.format(0), mFormat.format(getGearChange(requestedGear)), "'CHANGE TO GEAR " + requestedGear);
    }
    */

}


function onRapid(_x, _y, _z) {

    var x = xOutput.format(_x);
    var z = zOutput.format(_z);

    if (x || z) {
        if (pendingRadiusCompensation == -1) {
            writeBlock(getCode("MOTION_RAPID"), x, z);
        } else {
            pendingRadiusCompensation = -1;
            switch (radiusCompensation) {
                case RADIUS_COMPENSATION_OFF:
                    writeBlock(getCode("MOTION_RAPID"), getCode("TOOL_RADIUS_COMP_OFF"), x, z);
                    break;
                case RADIUS_COMPENSATION_LEFT:
                    writeBlock(getCode("MOTION_RAPID"), getCode("TOOL_RADIUS_COMP_LEFT"), x, z);
                    break;
                case RADIUS_COMPENSATION_RIGHT:
                    writeBlock(getCode("MOTION_RAPID"), getCode("TOOL_RADIUS_COMP_RIGHT"), x, z);
                    break;
                default:
                    error(localize("Invalid Radius Compensation Value!"));
            }
        }
    }

    forceXZF();
    forceMotionModal();

}


function onLinear(_x, _y, _z, feed) {

    var x = xOutput.format(_x);
    var z = zOutput.format(_z);
    var threadPitch = (isSpeedFeedSynchronizationActive()) ? pitchOutput.format(getParameter("operation:threadPitch")) : null;
    var f = (threadPitch) ? threadPitch : feedOutput.format(feed);
    
    if (x || z) {
        if (pendingRadiusCompensation == -1) {
            writeBlock((threadPitch) ? getCode("MOTION_THREAD_START") : getCode("MOTION_LINEAR"), x, z, f);
        } else {
            pendingRadiusCompensation = -1;
            switch (radiusCompensation) {
                case RADIUS_COMPENSATION_OFF:
                    writeBlock((threadPitch) ? getCode("MOTION_THREAD_START") : getCode("MOTION_LINEAR"), getCode("TOOL_RADIUS_COMP_OFF"), x, z, f);
                    break;
                case RADIUS_COMPENSATION_LEFT:
                    writeBlock((threadPitch) ? getCode("MOTION_THREAD_START") : getCode("MOTION_LINEAR"), getCode("TOOL_RADIUS_COMP_LEFT"), x, z, f);
                    break;
                case RADIUS_COMPENSATION_RIGHT:
                    writeBlock((threadPitch) ? getCode("MOTION_THREAD_START") : getCode("MOTION_LINEAR"), getCode("TOOL_RADIUS_COMP_RIGHT"), x, z, f);
                    break;
                default:
                    error(localize("Invalid Radius Compensation Value!"));
            }
        }
    }

    if (threadPitch) writeBlock(getCode("MOTION_THREAD_STOP"));

    forceXZF();
    forceMotionModal();

}


function onCircular(clockwise, cx, cy, cz, _x, _y, _z, feed) {

    // Allow for cirucular movements to be reversed from the properties
    clockwise = (clockwise && !properties.reverseCircular) ? true : false;

    var start = getCurrentPosition();

    var x = xOutput.format(_x);
    var z = zOutput.format(_z);
    var f = feedOutput.format(feed);

    var i = iOutput.format(cx - start.x, 0);
    var k = kOutput.format(cz - start.z, 0);

    if (isSpeedFeedSynchronizationActive()) {
        error(localize("Speed-feed synchronization is not supported for circular moves."));
        return;
    }
    
    if (pendingRadiusCompensation != -1) {
        error(localize("Radius compensation cannot be activated/deactivated for a circular move."));
        return;
    }

    if (isFullCircle()) {

        if (properties.useRadius || isHelical()) { // radius mode does not support full arcs
            linearize(tolerance);
            return;
        }

        switch (getCircularPlane()) {
            case PLANE_ZX:
                if (conversational) {
                    writeBlock(getCode(clockwise ? "MOTION_CIRCULAR_CW" : "MOTION_CIRCULAR_CCW"), i, k, f);
                } else {
                    writeBlock(getCode("PLANE_ZX"), getCode(clockwise ? "MOTION_CIRCULAR_CW" : "MOTION_CIRCULAR_CCW"), i, k, f);
                }
                break;
            default:
                linearize(tolerance);
        }

    } else if (!properties.useRadius) {

        switch (getCircularPlane()) {
            case PLANE_ZX:
                if (conversational) {
                    writeBlock(getCode(clockwise ? "MOTION_CIRCULAR_CW" : "MOTION_CIRCULAR_CCW"), x, z, i, k, f);
                } else {
                    writeBlock(getCode("PLANE_ZX"), getCode(clockwise ? "MOTION_CIRCULAR_CW" : "MOTION_CIRCULAR_CCW"), x, z, i, k, f);
                }
                break;
            default:
                linearize(tolerance);
        }

    } else { // use radius mode

        var radius = getCircularRadius();
        if (toDeg(getCircularSweep()) > (180 + 1e-9)) {
          radius = -radius; // allow up to <360 deg arcs
        }
        var r = rOutput.format(radius);

        switch (getCircularPlane()) {
            case PLANE_ZX:
                if (conversational) {
                    writeBlock(getCode(clockwise ? "MOTION_CIRCULAR_CW" : "MOTION_CIRCULAR_CCW"), x, z, r, f);
                } else {
                    writeBlock(getCode("PLANE_ZX"), getCode(clockwise ? "MOTION_CIRCULAR_CW" : "MOTION_CIRCULAR_CCW"), x, z, r, f);
                }
                break;
            default:
                linearize(tolerance);
        }

    }

    forceXZF();
    forceMotionModal();

}


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
    if (!conversational) writeComment("PROGRAM CLOSE");
    onCommand(COMMAND_COOLANT_OFF);
    onCommand(COMMAND_STOP_SPINDLE);
    onCommand(COMMAND_END);
}
