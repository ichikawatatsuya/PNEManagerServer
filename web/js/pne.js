var domain = location.hostname;

var $ = jQuery.noConflict();
var domainUrl = location.protocol + '//' + location.hostname + '/';

var domainValid = false;
var mailValid = false;
var pfValid = false;
var touValid = false;
var enabled = function() {
  if (domainValid && mailValid && pfValid && touValid) {
    $("#sendbutton2").removeAttr("disabled");
  } else {
    $("#sendbutton2").attr("disabled", "true");
  }
};

$('#sendbutton2').click( function() {
  sendForm();
});

$(function(){
  $("#domain-form").bind("keyup", function(e) {
    var re = new RegExp(/^[a-z0-9]{3,16}$/);
    var isValid = re.test($("#domain-form").val());
    if (isValid) {
      $.ajax({
        type: "GET",
        url: domainUrl + "api/domain/available",
        data: "domain=" + $("#domain-form").val() + "." + domain,
        dataType: "json",
        success: function(msg) {
          if (msg.result == true) {
            $("#available").html("使用可能です  http://" + $("#domain-form").val() + "." + domain);
            $("#available").css("color", "green");
            domainValid = true;
            enabled();
          } else {
            $("#available").html("すでに使用されています");
            $("#available").css("color", "red");
            domainValid = false;
            enabled();
          }
        }
      });
    } else {
      $("#available").html("3～16字までの半角英数字（小文字）で入力してください。");
      $("#available").css("color", "red");
      domainValid = false;
      enabled();
    }
  });
  $("#mail-form").bind("keyup", function(e){
    if ($("#mail-form").val() == "") {
      $("#mailvalid").html("必須項目です。");
      $("#mailvalid").css("color", "red");
      mailValid = false;
      enabled();
    }else{
      $("#mailvalid").html("");
      mailValid = true;
      enabled();
    }
  });

  $("#pfcheck").bind("click", function(e){
    if($("#pfcheck").attr("checked") == null) {
      pfValid = false;
    } else  {
      pfValid = true;
    }
    enabled();
  });

  $("#toucheck").bind("click", function(e){
    if($("#toucheck").attr("checked") == null) {
      touValid = false;
    } else  {
      touValid = true;
    }
    enabled();
  });

  $('#select-mode').change( function() {
    var mode = $('#select-mode option:selected').val();
    $('#mode-description').children().hide();
    $('#' + mode + '-mode').show();

    $('.backstretch:not(.backstretch:last)').remove();
    $('#photoCredit > *').remove();

    switch (mode)
    {
      case 'plane':
        $.backstretch('img/SNCF_TGV_PSE_Viaduc_de_Cize_-_Bolozon_blur.jpg', {speed: 1000});
        $('#photoCredit').append('<p>photo by : <a target="_blank" href="http://www.bahnbilder.ch">Kabelleger / David Gubler</a></p>');
        break;
      case 'renrakumou':
        $.backstretch('img/Washington_Dulles_International_Airport_at_Dusk_blur.jpg', {speed: 1000});
        $('#photoCredit').append('<p>photo by : <a target="_blank" href="http://commons.wikimedia.org/wiki/File:Washington_Dulles_International_Airport_at_Dusk.jpg">Joe Ravi</a></p>');
        break;
      case 'support':
        $.backstretch('img/ST_vs_Gloucester_-_Match_-_23_blur.jpg', {speed: 1000});
        $('#photoCredit').append('<p>photo by : <a target="_blank" href="http://commons.wikimedia.org/wiki/File:ST_vs_Gloucester_-_Match_-_23.JPG">PierreSelim</a></p>');
        break;
      default:
        $.backstretch('bg1.png', {speed: 1000});
        break;
    }
  });
});

function sendForm() {
  $.ajax({
    type: "POST",
    url: domainUrl + "api/sns/apply",
    data: "domain=" + $("#domain-form").val() + '.' + domain + "&email=" + $("#mail-form").val() + "&options=mode:" + $("#select-mode option:selected").val(),
    dataType: "json",
    success: function(json){
      if (json.result == true){
        document.location = domainUrl + 'success.html'
      }else{
        alert("エラーが発生しました。\n入力内容を確認して下さい。");
      }
    },
    error: function(json){
      if (0 <= json.responseText.indexOf("email") && 0 <= json.responseText.indexOf("already"))
      {
        alert("そのE-mailは既に使用されています。\n1つのメールアドレスで申し込み可能なSNSは1つとなっています。");
      }
      else if (0 <= json.responseText.indexOf("valid"))
      {
        alert("E-mailに使用できない文字が含まれています。");
      }
      else
      {
        alert("エラーが発生しました。\n入力内容を確認して下さい。");
      }
    }
  });
};
