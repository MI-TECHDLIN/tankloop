{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      document.getElementById('record-startup')?.remove();
    } catch (_) {
      const status = document.getElementById('startup-status');
      if (status) status.textContent = 'The record viewer could not start. Reload to retry. No current water-quality claim can be made.';
      document.querySelectorAll('.startup-skeleton').forEach((item) => item.remove());
    }
  }
});
