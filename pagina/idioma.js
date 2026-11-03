// The page's language: the one chosen with a flag (kept for every page of the site), or else
// the browser's first one among Portuguese, Spanish and English, or else English. Runs in
// <head>, so the page is drawn in that language from the start.
(function () {
  var raiz = document.documentElement, idiomas = ["pt-BR", "es", "en"], idioma = null;
  try { idioma = localStorage.getItem("idioma"); } catch (e) {}
  if (idiomas.indexOf(idioma) < 0) {
    idioma = "en";
    var preferidos = navigator.languages || [navigator.language || ""];
    for (var i = 0; i < preferidos.length; i++) {
      var codigo = String(preferidos[i]).toLowerCase().slice(0, 2);
      if (codigo === "pt") { idioma = "pt-BR"; break; }
      if (codigo === "es" || codigo === "en") { idioma = codigo; break; }
    }
  }
  function aplicar() {
    raiz.lang = idioma;
    raiz.setAttribute("data-idioma", idioma);
    var botoes = document.querySelectorAll("[data-idioma-botao]");
    for (var i = 0; i < botoes.length; i++) {
      botoes[i].setAttribute("aria-pressed", String(botoes[i].getAttribute("data-idioma-botao") === idioma));
    }
  }
  raiz.classList.add("js");
  aplicar();
  document.addEventListener("DOMContentLoaded", aplicar);
  document.addEventListener("click", function (evento) {
    var botao = evento.target.closest && evento.target.closest("[data-idioma-botao]");
    if (!botao) return;
    idioma = botao.getAttribute("data-idioma-botao");
    try { localStorage.setItem("idioma", idioma); } catch (e) {}
    aplicar();
  });
})();
