(function() {
    // Create the connector object
    var myConnector = tableau.makeConnector();
    // Define the schema
    myConnector.getSchema = function(schemaCallback) {
        var cols = [{
            id: "id",
            dataType: tableau.dataTypeEnum.int
        }, {
            id: "time",
            alias: "time",
            dataType: tableau.dataTypeEnum.datetime
        }];

        var tableSchema = {
            id: "timekiller",
            alias: "timekiller",
            columns: cols
        };
        schemaCallback([tableSchema]);
    };
    
    // Download the data
    myConnector.getData = function(table, doneCallback) {
        var rowCnt = {rowCnt};
        var id = 1;
        var tableData = [];
        while (true) {
            // current time
            var currentdate = new Date(); 
            var datetime = "" + currentdate.getFullYear() + "-"
                + (currentdate.getMonth()+1) + "-"
                + currentdate.getDate() + " "
                + currentdate.getHours() + ":"  
                + currentdate.getMinutes() + ":" 
                + currentdate.getSeconds();
            
            // add one row
            tableData.push({
                "id": id,
                "time": datetime
            });
            // console.log("id: " + id + ", time: " + datetime)

            id++;
            if (id > rowCnt) break;            
            // wait for 1 sec
            var start = new Date().getTime();
            var end = start;
            while(end < start + 1000) {
              end = new Date().getTime();
           }
        }
        
        table.appendRows(tableData);
        doneCallback();
    };

    tableau.registerConnector(myConnector);

    // Create event listeners for when the user submits the form
    // document.onload = function() {
    //     console.log("load event");
    //     var button = document.getElementById('submitButton');
    //     button.addEventListener('click', function(e){
    //         tableau.connectionName = "timekiller"; // This will be the data source name in Tableau
    //         tableau.submit(); // This sends the connector object to Tableau
    //     });
    // };
    
    // Create event listeners for when the user submits the form
    $(document).ready(function() {
        $("#submitButton").click(function() {
            tableau.connectionName = "timekiller"; // This will be the data source name in Tableau
            tableau.submit(); // This sends the connector object to Tableau
        });
    });
})();
