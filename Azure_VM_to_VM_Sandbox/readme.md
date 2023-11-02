Lab environment for testing connectivity between Virtual Machines in separate Virtual Networks.

Optional configurations are as follows:
\r\nSame Region or multi Region
Virtual Network Gateway or Virtual Network Peering connection
Azure Firewall
Windows or Linux Virtual Machines


You may either clone this repro and deploy with Bicep or use the easy deploy below:


[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fjimgodden%2FVM_to_VM%2Fmain%2Fsrc%2Fmain.json)


Diagram of the infrastructure with all optional components

![Diagram of the infrastructure with all optional components](diagram.drawio.png)

Note: This Diagram is in this repository, and can be modified via https://app.diagrams.net/
