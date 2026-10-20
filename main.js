// American Roadhouse - shared interactions
document.addEventListener('DOMContentLoaded', () => {

  /* Sticky nav compaction */
  const nav = document.getElementById('site-nav');
  const onScroll = () => {
    if (window.scrollY > 40) nav?.classList.add('scrolled');
    else nav?.classList.remove('scrolled');
  };
  window.addEventListener('scroll', onScroll, { passive:true });
  onScroll();

  /* Mobile menu */
  const menuBtn = document.getElementById('menu-open');
  const menuCloseBtn = document.getElementById('menu-close');
  const mobileMenu = document.getElementById('mobile-menu');
  menuBtn?.addEventListener('click', () => mobileMenu?.classList.add('open'));
  menuCloseBtn?.addEventListener('click', () => mobileMenu?.classList.remove('open'));
  mobileMenu?.querySelectorAll('a').forEach(a => a.addEventListener('click', () => mobileMenu.classList.remove('open')));

  /* Reveal on scroll */
  const revealEls = document.querySelectorAll('.reveal');
  if ('IntersectionObserver' in window && revealEls.length){
    const io = new IntersectionObserver((entries) => {
      entries.forEach(e => { if (e.isIntersecting){ e.target.classList.add('in'); io.unobserve(e.target); } });
    }, { threshold: 0.12 });
    revealEls.forEach(el => io.observe(el));
  } else {
    revealEls.forEach(el => el.classList.add('in'));
  }

  /* FAQ accordion */
  document.querySelectorAll('.faq-item').forEach(item => {
    const btn = item.querySelector('.faq-question');
    const ans = item.querySelector('.faq-answer');
    btn?.addEventListener('click', () => {
      const isOpen = item.classList.contains('open');
      document.querySelectorAll('.faq-item.open').forEach(other => {
        if (other !== item){
          other.classList.remove('open');
          other.querySelector('.faq-answer').style.maxHeight = null;
        }
      });
      item.classList.toggle('open', !isOpen);
      ans.style.maxHeight = !isOpen ? ans.scrollHeight + 'px' : null;
    });
  });

  /* Gallery filters */
  const filters = document.querySelectorAll('.gallery-filter');
  const items = document.querySelectorAll('.gallery-item');
  filters.forEach(f => f.addEventListener('click', () => {
    filters.forEach(x => x.classList.remove('active'));
    f.classList.add('active');
    const cat = f.dataset.filter;
    items.forEach(it => {
      it.style.display = (cat === 'all' || it.dataset.cat === cat) ? '' : 'none';
    });
  }));

  /* Lightbox */
  const lightbox = document.getElementById('lightbox');
  if (lightbox){
    const lbImg = document.getElementById('lightbox-img');
    const gallery = Array.from(document.querySelectorAll('.gallery-item img'));
    let idx = 0;
    const show = (i) => {
      idx = (i + gallery.length) % gallery.length;
      lbImg.src = gallery[idx].src;
      lbImg.alt = gallery[idx].alt;
    };
    document.querySelectorAll('.gallery-item').forEach((el, i) => {
      el.addEventListener('click', () => { show(i); lightbox.classList.add('open'); });
    });
    document.getElementById('lightbox-close')?.addEventListener('click', () => lightbox.classList.remove('open'));
    document.getElementById('lightbox-prev')?.addEventListener('click', () => show(idx - 1));
    document.getElementById('lightbox-next')?.addEventListener('click', () => show(idx + 1));
    lightbox.addEventListener('click', (e) => { if (e.target === lightbox) lightbox.classList.remove('open'); });
    document.addEventListener('keydown', (e) => {
      if (!lightbox.classList.contains('open')) return;
      if (e.key === 'Escape') lightbox.classList.remove('open');
      if (e.key === 'ArrowRight') show(idx + 1);
      if (e.key === 'ArrowLeft') show(idx - 1);
    });
  }

  /* Tabs (Booking / Contact) */
  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const target = btn.dataset.tab;
      const group = btn.closest('.tabs').dataset.group;
      document.querySelectorAll(`.tabs[data-group="${group}"] .tab-btn`).forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      document.querySelectorAll(`.tab-panel[data-group="${group}"]`).forEach(p => p.classList.remove('active'));
      document.querySelector(`.tab-panel[data-group="${group}"][data-tab="${target}"]`)?.classList.add('active');
    });
  });

  /* Deep-link tab activation, e.g. contact.html?tab=booking */
  const params = new URLSearchParams(window.location.search);
  const wantedTab = params.get('tab');
  if (wantedTab){
    const btn = document.querySelector(`.tab-btn[data-tab="${wantedTab}"]`);
    btn?.click();
    setTimeout(() => document.getElementById('forms')?.scrollIntoView({ behavior:'smooth' }), 200);
  }

  /* Form submission -> sent to the owner's inbox via Web3Forms, then confirmation state */
  document.querySelectorAll('form[data-inquiry-form]').forEach(form => {
    const submitBtn = form.querySelector('button[type="submit"]');
    const errorBox = form.querySelector('.form-error');
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      if (!form.checkValidity()){ form.reportValidity(); return; }
      const originalLabel = submitBtn ? submitBtn.textContent : '';
      if (submitBtn){ submitBtn.disabled = true; submitBtn.textContent = 'Sending…'; }
      errorBox?.classList.remove('show');
      try {
        const res = await fetch('https://api.web3forms.com/submit', {
          method: 'POST',
          headers: { 'Accept': 'application/json' },
          body: new FormData(form)
        });
        const result = await res.json();
        if (result.success){
          form.style.display = 'none';
          const confirm = form.parentElement.querySelector('.form-confirm');
          confirm?.classList.add('show');
        } else {
          throw new Error(result.message || 'Submission failed');
        }
      } catch (err){
        if (errorBox){
          errorBox.textContent = "Something went wrong sending your request - please try again, or call us at 0915 875 4860.";
          errorBox.classList.add('show');
        }
      } finally {
        if (submitBtn){ submitBtn.disabled = false; submitBtn.textContent = originalLabel; }
      }
    });
  });

  /* Quick availability card -> routes to booking form (no live inventory yet) */
  document.getElementById('quick-availability')?.addEventListener('submit', (e) => {
    e.preventDefault();
    const ci = document.getElementById('qa-checkin')?.value || '';
    const co = document.getElementById('qa-checkout')?.value || '';
    const guests = document.getElementById('qa-guests')?.value || '';
    const qs = new URLSearchParams({ tab:'booking', checkin:ci, checkout:co, guests }).toString();
    window.location.href = `contact.html?${qs}#forms`;
  });

  /* Prefill booking form from quick-availability query params */
  const ciParam = params.get('checkin'), coParam = params.get('checkout'), gParam = params.get('guests');
  if (ciParam) document.getElementById('bk-checkin') && (document.getElementById('bk-checkin').value = ciParam);
  if (coParam) document.getElementById('bk-checkout') && (document.getElementById('bk-checkout').value = coParam);
  if (gParam) document.getElementById('bk-guests') && (document.getElementById('bk-guests').value = gParam);

});
