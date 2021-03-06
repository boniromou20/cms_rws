function printHtml(html, landscape, title, have_title) {
  var printFrame = document.createElement('iframe');

  printFrame.name = "printFrame";
  printFrame.style.position = "absolute";
  printFrame.style.top = "-1000000px";
  document.body.appendChild(printFrame);

  var frameDoc = printFrame.contentWindow ? printFrame.contentWindow : printFrame.contentDocument.document ? printFrame.contentDocument.document : printFrame.contentDocument;
  frameDoc.document.open();
  frameDoc.document.write('<html><head><title>');
  if (typeof title !== 'undefined' && title) {
    frameDoc.document.write(title);
  }
  frameDoc.document.write('</title>');
  if ( typeof landscape !== 'undefined' && landscape ){   
    frameDoc.document.write('<style>@media print{@page {size: landscape; '); //only work on Chrome
    if ( typeof have_title !== 'undefined' && have_title )
      frameDoc.document.write('}}</style>');
    else
      frameDoc.document.write('margin: 0;}}</style>');
  }
  frameDoc.document.write('</head><body>');
  frameDoc.document.write(html);
  frameDoc.document.write('</body></html>');
  frameDoc.document.close();

  setTimeout(function () {
      window.frames["printFrame"].focus();
      window.frames["printFrame"].print();
      document.body.removeChild(printFrame);
  }, 1000);

  return false;
}
