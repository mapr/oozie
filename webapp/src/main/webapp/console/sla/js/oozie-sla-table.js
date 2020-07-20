/**
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

var oTable;
var columnsToShow = [
    {"data": null, "orderable": false, "width": "0.1%", "visible": true},
    {"data": "id"},
    {"data": "slaStatus"},
    {"data": "nominalTimeTZ", "defaultContent": ""},
    {"data": "expectedStartTZ", "defaultContent": ""},
    {"data": "actualStartTZ", "defaultContent": ""},
    {"data": "startDiff", "defaultContent": ""},
    {"data": "expectedEndTZ"},
    {"data": "actualEndTZ", "defaultContent": ""},
    {"data": "endDiff", "defaultContent": ""},
    {"data": "expectedDuration", "defaultContent": "", "visible": false},
    {"data": "actualDuration", "defaultContent": "", "visible": false},
    {"data": "durDiff", "defaultContent": "", "visible": false},
    {"data": "slaMisses", "defaultContent": ""},
    {"data": "jobStatus", "defaultContent": ""},
    {"data": "parentId", "defaultContent": "", "visible": false},
    {"data": "appName", "visible": false},
    {"data": "slaAlertStatus", "visible": false},
];


function initializeTable() {
    var table = $('#sla_table').DataTable(
      {
          "jQueryUI": true,
          "dom": '<"clear"><"fg-toolbar ui-widget-header ui-corner-tl ui-corner-tr ui-helper-clearfix"fBlr>t<"fg-toolbar ui-widget-header ui-corner-bl ui-corner-br ui-helper-clearfix"ip>',
          "stateSave": true,
          "scrollY": "300px",
          "scrollX": "100%",
          "paging": true,
          "pagingType": "full_numbers",
          "buttons": [
              "copy",
              {
                  "extend": "csv",
                  // Ignore column 0
                  "columns": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
              },
              {
                  "extend": "colvis",
                  "columns": ":gt(0)",
                  "text": "Show/Hide columns",
                  "postfixButtons": [ 'colvisRestore' ],
              },
          ],
          "columns": columnsToShow,
          "rowCallback": function (row, data, iDisplayIndex, iDisplayIndexFull) {
              var rowAllColumns = row.cells;
              $(rowAllColumns[1]).html(
                '<a href="/oozie?job=' + data.id + '" target="_blank">' + data.id
                + '</a>');
              $(rowAllColumns[15]).html(
                '<a href="/oozie?job=' + data.parentId + '" target="_blank">'
                + data.parentId + '</a>');
              if (data.slaStatus == "MISS") {
                  $(rowAllColumns[2]).addClass('sla-status-miss');
              }
              // Changing only the html with readable text to preserve sort order.
              if (data.startDiff || data.startDiff == 0) {
                  $(rowAllColumns[6]).html(timeElapsed(data.startDiff));
              }
              if (data.endDiff || data.endDiff == 0) {
                  $(rowAllColumns[9]).html(timeElapsed(data.endDiff));
              }
              if (data.expectedDuration == -1) {
                  $(rowAllColumns[10]).html("");
              } else {
                  $(rowAllColumns[10]).html(timeElapsed(data.expectedDuration));
              }
              if (data.actualDuration == -1) {
                  $(rowAllColumns[11]).html("");
              } else {
                  $(rowAllColumns[11]).html(timeElapsed(data.actualDuration));
              }
              if (data.durDiff || data.durDiff == 0) {
                  $(rowAllColumns[12]).html(timeElapsed(data.durDiff));
              }
              $("td:first", row).html(iDisplayIndexFull + 1);
              return row;
          },
          "order": [[3, 'desc']]
      });
    return table;
}

function drawTable(jsonData) {
    var currentTime = new Date().getTime();

    for (var i = 0; i < jsonData.slaSummaryList.length; i++) {
        var slaMisses = "";
        var slaSummary = jsonData.slaSummaryList[i];

        slaSummary.nominalTimeTZ = new Date(slaSummary.nominalTime).toUTCString();
        if (slaSummary.expectedStart) {
            slaSummary.expectedStartTZ = new Date(slaSummary.expectedStart).toUTCString();
        }
        if (slaSummary.actualStart) {
            slaSummary.actualStartTZ = new Date(slaSummary.actualStart).toUTCString();
        }
        if (slaSummary.expectedEnd) {
            slaSummary.expectedEndTZ = new Date(slaSummary.expectedEnd).toUTCString();
        }
        if (slaSummary.actualEnd) {
            slaSummary.actualEndTZ = new Date(slaSummary.actualEnd).toUTCString();
        }
        if (slaSummary.expectedStart && slaSummary.actualStart) {
            // timeElapsed in oozie-sla.js
            slaSummary.startDiff = slaSummary.actualStart - slaSummary.expectedStart;
        }
        if (slaSummary.expectedEnd && slaSummary.actualEnd) {
            slaSummary.endDiff = slaSummary.actualEnd - slaSummary.expectedEnd;
        }
        if (slaSummary.actualDuration != -1 && slaSummary.expectedDuration != -1) {
            slaSummary.durDiff = slaSummary.actualDuration - slaSummary.expectedDuration;
        }
        slaSummary.slaMisses = slaSummary.eventStatus;
    }

    if (!oTable) {
        oTable = initializeTable();
    }
    oTable.clear();
    oTable.rows.add(jsonData.slaSummaryList).draw();
}
