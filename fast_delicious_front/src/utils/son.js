/**
 * Joue un petit carillon de notification (2 notes), généré directement en Web Audio API
 * — pas besoin de fichier audio externe. Échoue silencieusement si le navigateur bloque
 * l'audio (ex: aucune interaction utilisateur préalable sur la page).
 */
export function jouerNotification() {
  try {
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    const ctx = new AudioCtx();
    const maintenant = ctx.currentTime;

    [660, 880].forEach((frequence, i) => {
      const debut = maintenant + i * 0.15;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = "sine";
      osc.frequency.value = frequence;

      gain.gain.setValueAtTime(0.0001, debut);
      gain.gain.exponentialRampToValueAtTime(0.35, debut + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, debut + 0.3);

      osc.connect(gain).connect(ctx.destination);
      osc.start(debut);
      osc.stop(debut + 0.32);
    });

    // Referme le contexte audio après usage pour ne pas en accumuler.
    setTimeout(() => ctx.close(), 600);
  } catch {
    // Audio indisponible : on ignore silencieusement, ce n'est pas critique.
  }
}
