// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery_ujs
//= require turbolinks
//= require cloudinary
//= require auth/auth_modals_and_navbar.js
//= require pulsate.min.js
//= require_tree .

$(document).ready(function(){
    $('.tabs').tabs();
    $('.modal').modal();
    $('.collapsible').collapsible();
    $('.dropdown-trigger').dropdown();
    $('select').formSelect();
    $('.datepicker').datepicker({
        format: "yyyy-mm-dd"
    });
    $('select').formSelect();
});

$(document).on('turbolinks:load', function() {
    $('.tabs').tabs();
    $('.modal').modal();
    $('.collapsible').collapsible();
    $('.dropdown-trigger').dropdown();
    $('select').formSelect();
    $('.datepicker').datepicker({
        format: "yyyy-mm-dd"
    });
    $('select').formSelect();
});

$(document).on('click','.edit_nested_object,.add_nested_element', function() {
    $('.tabs').tabs();
    $('.modal').modal();
    $('.collapsible').collapsible();
    $('.dropdown-trigger').dropdown();
    $('select').formSelect();
    $('.datepicker').datepicker({
        format: "yyyy-mm-dd"
    });
    $('select').formSelect();
});