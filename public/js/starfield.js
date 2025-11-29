// Constellation Overwatch - Starfield Background
// Three.js cosmic scene with stars, nebulae, galaxies, and UFOs

(function() {
    'use strict';

    // Detect mobile device
    const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);

    // Epic Star Wars / UAP Cosmic Scene
    const canvas = document.getElementById('starfield');
    if (!canvas) {
        console.warn('Starfield canvas not found');
        return;
    }

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 5000);
    const renderer = new THREE.WebGLRenderer({ canvas: canvas, alpha: true, antialias: !isMobile });

    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, isMobile ? 1.5 : 2));

    // ========== CONFIGURATION ==========
    const starCount = isMobile ? 2000 : 4000;
    const nebulaCount = isMobile ? 400 : 800;
    const dustCount = isMobile ? 300 : 600;
    const galaxyCount = isMobile ? 15 : 30;
    const ufoCount = isMobile ? 3 : 6;
    const shootingStarCount = isMobile ? 2 : 4;

    // Star colors (realistic stellar classification)
    const starColors = [
        0xffffff, // White (main sequence)
        0xaaccff, // Blue-white (hot stars)
        0xffeedd, // Warm white
        0xffcc99, // Orange (cooler stars)
        0xff9966, // Red giants
        0x99ccff, // Blue
        0x00ffff, // Cyan (theme color)
    ];

    // ========== MULTI-COLORED TWINKLING STARS ==========
    const starsGeometry = new THREE.BufferGeometry();
    const starsVertices = [];
    const starColorData = [];
    const starSizes = [];
    const starTwinklePhases = [];

    for (let i = 0; i < starCount; i++) {
        const x = (Math.random() - 0.5) * 3000;
        const y = (Math.random() - 0.5) * 3000;
        const z = -Math.random() * 3000;
        starsVertices.push(x, y, z);

        // Random star color
        const color = new THREE.Color(starColors[Math.floor(Math.random() * starColors.length)]);
        starColorData.push(color.r, color.g, color.b);

        // Variable star sizes (some brighter stars)
        const size = Math.random() < 0.1 ? (isMobile ? 3 : 4) : (isMobile ? 1 : 1.5);
        starSizes.push(size);

        // Random twinkle phase
        starTwinklePhases.push(Math.random() * Math.PI * 2);
    }

    starsGeometry.setAttribute('position', new THREE.Float32BufferAttribute(starsVertices, 3));
    starsGeometry.setAttribute('color', new THREE.Float32BufferAttribute(starColorData, 3));
    starsGeometry.setAttribute('size', new THREE.Float32BufferAttribute(starSizes, 1));

    const starsMaterial = new THREE.PointsMaterial({
        size: isMobile ? 1.5 : 2,
        transparent: true,
        opacity: 0.9,
        vertexColors: true,
        blending: THREE.AdditiveBlending,
        sizeAttenuation: true
    });

    const stars = new THREE.Points(starsGeometry, starsMaterial);
    scene.add(stars);

    // ========== VOLUMETRIC NEBULA CLOUDS ==========
    // Multiple nebula layers with different colors for depth
    const nebulaLayers = [];
    const nebulaColors = [
        { color: 0x00ffff, opacity: 0.4 },  // Cyan (brand)
        { color: 0x0088ff, opacity: 0.3 },  // Deep blue
        { color: 0xff00ff, opacity: 0.15 }, // Magenta
        { color: 0x8800ff, opacity: 0.2 },  // Purple
        { color: 0x00ff88, opacity: 0.15 }, // Teal
    ];

    nebulaColors.forEach((config, layerIndex) => {
        const nebulaGeometry = new THREE.BufferGeometry();
        const nebulaVertices = [];
        const count = Math.floor(nebulaCount / nebulaColors.length);

        for (let i = 0; i < count; i++) {
            // Cluster nebula particles for more realistic cloud formations
            const clusterX = (Math.random() - 0.5) * 2500;
            const clusterY = (Math.random() - 0.5) * 2500;
            const clusterZ = -Math.random() * 2000 - 500;

            // Add some particles around cluster center
            const spread = 200 + Math.random() * 300;
            const x = clusterX + (Math.random() - 0.5) * spread;
            const y = clusterY + (Math.random() - 0.5) * spread;
            const z = clusterZ + (Math.random() - 0.5) * spread;
            nebulaVertices.push(x, y, z);
        }

        nebulaGeometry.setAttribute('position', new THREE.Float32BufferAttribute(nebulaVertices, 3));

        const nebulaMaterial = new THREE.PointsMaterial({
            color: config.color,
            size: isMobile ? (4 + layerIndex * 2) : (6 + layerIndex * 3),
            transparent: true,
            opacity: config.opacity,
            blending: THREE.AdditiveBlending,
            sizeAttenuation: true
        });

        const nebula = new THREE.Points(nebulaGeometry, nebulaMaterial);
        scene.add(nebula);
        nebulaLayers.push({ mesh: nebula, geometry: nebulaGeometry, speed: 0.3 + layerIndex * 0.1 });
    });

    // ========== COSMIC DUST PARTICLES ==========
    const dustGeometry = new THREE.BufferGeometry();
    const dustVertices = [];

    for (let i = 0; i < dustCount; i++) {
        const x = (Math.random() - 0.5) * 2000;
        const y = (Math.random() - 0.5) * 2000;
        const z = -Math.random() * 1500;
        dustVertices.push(x, y, z);
    }

    dustGeometry.setAttribute('position', new THREE.Float32BufferAttribute(dustVertices, 3));

    const dustMaterial = new THREE.PointsMaterial({
        color: 0x666688,
        size: isMobile ? 0.5 : 1,
        transparent: true,
        opacity: 0.3,
        blending: THREE.AdditiveBlending
    });

    const dust = new THREE.Points(dustGeometry, dustMaterial);
    scene.add(dust);

    // ========== DISTANT GALAXIES ==========
    const galaxies = [];

    for (let i = 0; i < galaxyCount; i++) {
        const galaxyGeometry = new THREE.BufferGeometry();
        const galaxyVertices = [];
        const galaxyColors = [];
        const particleCount = isMobile ? 50 : 100;

        // Galaxy center position (far away)
        const centerX = (Math.random() - 0.5) * 4000;
        const centerY = (Math.random() - 0.5) * 4000;
        const centerZ = -2000 - Math.random() * 2000;

        // Create spiral galaxy shape
        const arms = 2 + Math.floor(Math.random() * 3);
        const galaxyColor = new THREE.Color(starColors[Math.floor(Math.random() * 4)]);

        for (let j = 0; j < particleCount; j++) {
            const arm = j % arms;
            const distance = Math.random() * (isMobile ? 60 : 100);
            const angle = (arm / arms) * Math.PI * 2 + distance * 0.02 + Math.random() * 0.5;

            const x = centerX + Math.cos(angle) * distance;
            const y = centerY + Math.sin(angle) * distance + (Math.random() - 0.5) * 20;
            const z = centerZ + (Math.random() - 0.5) * 30;

            galaxyVertices.push(x, y, z);

            // Gradient color from center to edges
            const brightness = 1 - (distance / 100) * 0.5;
            galaxyColors.push(
                galaxyColor.r * brightness,
                galaxyColor.g * brightness,
                galaxyColor.b * brightness
            );
        }

        galaxyGeometry.setAttribute('position', new THREE.Float32BufferAttribute(galaxyVertices, 3));
        galaxyGeometry.setAttribute('color', new THREE.Float32BufferAttribute(galaxyColors, 3));

        const galaxyMaterial = new THREE.PointsMaterial({
            size: isMobile ? 2 : 3,
            transparent: true,
            opacity: 0.6,
            vertexColors: true,
            blending: THREE.AdditiveBlending
        });

        const galaxy = new THREE.Points(galaxyGeometry, galaxyMaterial);
        scene.add(galaxy);
        galaxies.push({ mesh: galaxy, rotationSpeed: (Math.random() - 0.5) * 0.001 });
    }

    // ========== UFO / UAP CRAFT ==========
    const ufos = [];

    function createUFO() {
        const ufoGroup = new THREE.Group();

        // Main saucer body (disc shape using torus)
        const saucerGeometry = new THREE.TorusGeometry(isMobile ? 8 : 12, isMobile ? 2 : 3, 8, 16);
        const saucerMaterial = new THREE.MeshBasicMaterial({
            color: 0x334455,
            transparent: true,
            opacity: 0.8
        });
        const saucer = new THREE.Mesh(saucerGeometry, saucerMaterial);
        saucer.rotation.x = Math.PI / 2;
        ufoGroup.add(saucer);

        // Cockpit dome
        const domeGeometry = new THREE.SphereGeometry(isMobile ? 4 : 6, 16, 8, 0, Math.PI * 2, 0, Math.PI / 2);
        const domeMaterial = new THREE.MeshBasicMaterial({
            color: 0x00ffff,
            transparent: true,
            opacity: 0.6
        });
        const dome = new THREE.Mesh(domeGeometry, domeMaterial);
        dome.position.y = 1;
        ufoGroup.add(dome);

        // Pulsing lights around rim
        const lightCount = 8;
        const lights = [];
        for (let i = 0; i < lightCount; i++) {
            const lightGeometry = new THREE.SphereGeometry(isMobile ? 0.8 : 1.2, 8, 8);
            const lightMaterial = new THREE.MeshBasicMaterial({
                color: i % 2 === 0 ? 0x00ffff : 0xff00ff,
                transparent: true,
                opacity: 0.9
            });
            const light = new THREE.Mesh(lightGeometry, lightMaterial);
            const angle = (i / lightCount) * Math.PI * 2;
            const radius = isMobile ? 9 : 13;
            light.position.set(Math.cos(angle) * radius, 0, Math.sin(angle) * radius);
            ufoGroup.add(light);
            lights.push(light);
        }

        // Engine glow (bottom)
        const engineGeometry = new THREE.CircleGeometry(isMobile ? 5 : 7, 16);
        const engineMaterial = new THREE.MeshBasicMaterial({
            color: 0x00ffff,
            transparent: true,
            opacity: 0.4,
            side: THREE.DoubleSide
        });
        const engine = new THREE.Mesh(engineGeometry, engineMaterial);
        engine.rotation.x = Math.PI / 2;
        engine.position.y = -2;
        ufoGroup.add(engine);

        return { group: ufoGroup, lights, engine, engineMaterial };
    }

    for (let i = 0; i < ufoCount; i++) {
        const ufo = createUFO();
        ufo.group.position.set(
            (Math.random() - 0.5) * 2000,
            (Math.random() - 0.5) * 1000,
            -500 - Math.random() * 1500
        );
        ufo.group.scale.setScalar(isMobile ? 0.5 : 0.8);

        // Movement properties
        ufo.velocity = new THREE.Vector3(
            (Math.random() - 0.5) * 3,
            (Math.random() - 0.5) * 1,
            Math.random() * 2 + 1
        );
        ufo.wobble = Math.random() * Math.PI * 2;
        ufo.wobbleSpeed = 0.02 + Math.random() * 0.02;
        ufo.lightPhase = Math.random() * Math.PI * 2;

        scene.add(ufo.group);
        ufos.push(ufo);
    }

    // ========== SHOOTING STARS / METEORS ==========
    const shootingStars = [];

    function createShootingStar() {
        const geometry = new THREE.BufferGeometry();
        const trailLength = isMobile ? 15 : 25;
        const positions = new Float32Array(trailLength * 3);
        const colors = new Float32Array(trailLength * 3);

        geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
        geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));

        const material = new THREE.LineBasicMaterial({
            vertexColors: true,
            transparent: true,
            opacity: 0.8,
            blending: THREE.AdditiveBlending
        });

        const line = new THREE.Line(geometry, material);

        return {
            line,
            geometry,
            trailLength,
            active: false,
            position: new THREE.Vector3(),
            velocity: new THREE.Vector3(),
            trail: [],
            cooldown: Math.random() * 200
        };
    }

    for (let i = 0; i < shootingStarCount; i++) {
        const shootingStar = createShootingStar();
        scene.add(shootingStar.line);
        shootingStars.push(shootingStar);
    }

    function activateShootingStar(star) {
        star.active = true;
        star.position.set(
            (Math.random() - 0.5) * 2000,
            500 + Math.random() * 500,
            -500 - Math.random() * 1000
        );
        star.velocity.set(
            (Math.random() - 0.5) * 20,
            -15 - Math.random() * 10,
            5 + Math.random() * 5
        );
        star.trail = [];
    }

    // ========== HYPERSPACE STREAK ENHANCEMENT ==========
    const hyperspaceStreaks = [];
    const streakCount = isMobile ? 50 : 100;

    for (let i = 0; i < streakCount; i++) {
        const geometry = new THREE.BufferGeometry();
        const positions = new Float32Array(6); // 2 points
        geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));

        const material = new THREE.LineBasicMaterial({
            color: 0xffffff,
            transparent: true,
            opacity: 0,
            blending: THREE.AdditiveBlending
        });

        const line = new THREE.Line(geometry, material);
        scene.add(line);

        hyperspaceStreaks.push({
            line,
            geometry,
            material,
            x: (Math.random() - 0.5) * 1500,
            y: (Math.random() - 0.5) * 1500,
            z: -Math.random() * 2000,
            speed: 10 + Math.random() * 20,
            active: Math.random() < 0.3
        });
    }

    camera.position.z = 1;

    // ========== ANIMATION LOOP ==========
    let lastTime = Date.now();
    const targetFPS = isMobile ? 30 : 60;
    const frameInterval = 1000 / targetFPS;
    let animationTime = 0;

    function animate() {
        requestAnimationFrame(animate);

        const currentTime = Date.now();
        const deltaTime = currentTime - lastTime;

        if (deltaTime < frameInterval) return;
        lastTime = currentTime - (deltaTime % frameInterval);
        animationTime += deltaTime * 0.001;

        // ===== STAR MOVEMENT WITH TWINKLING =====
        const positions = starsGeometry.attributes.position.array;
        const colors = starsGeometry.attributes.color.array;
        const speed = isMobile ? 1.5 : 2;

        for (let i = 0; i < positions.length; i += 3) {
            positions[i + 2] += speed;

            if (positions[i + 2] > 300) {
                positions[i] = (Math.random() - 0.5) * 3000;
                positions[i + 1] = (Math.random() - 0.5) * 3000;
                positions[i + 2] = -3000;
            }

            // Subtle twinkling effect
            const starIndex = i / 3;
            const twinkle = Math.sin(animationTime * 3 + starTwinklePhases[starIndex]) * 0.2 + 0.8;
            const baseIndex = starIndex * 3;
            if (colors[baseIndex] !== undefined) {
                // Modulate brightness slightly
                const brightnessMod = 0.8 + twinkle * 0.2;
            }
        }
        starsGeometry.attributes.position.needsUpdate = true;

        // ===== NEBULA LAYER ANIMATION =====
        nebulaLayers.forEach((layer, index) => {
            const nebulaPositions = layer.geometry.attributes.position.array;
            const nebulaSpeed = isMobile ? layer.speed * 0.5 : layer.speed;

            for (let i = 0; i < nebulaPositions.length; i += 3) {
                nebulaPositions[i + 2] += nebulaSpeed;

                // Gentle swirling motion
                nebulaPositions[i] += Math.sin(animationTime + i) * 0.1;
                nebulaPositions[i + 1] += Math.cos(animationTime + i) * 0.1;

                if (nebulaPositions[i + 2] > 200) {
                    nebulaPositions[i + 2] = -2000 - Math.random() * 500;
                    nebulaPositions[i] = (Math.random() - 0.5) * 2500;
                    nebulaPositions[i + 1] = (Math.random() - 0.5) * 2500;
                }
            }
            layer.geometry.attributes.position.needsUpdate = true;

            // Pulsing opacity
            layer.mesh.material.opacity = layer.mesh.material.opacity * 0.99 +
                (nebulaColors[index].opacity * (0.8 + Math.sin(animationTime * 0.5 + index) * 0.2)) * 0.01;
        });

        // ===== DUST ANIMATION =====
        const dustPositions = dustGeometry.attributes.position.array;
        for (let i = 0; i < dustPositions.length; i += 3) {
            dustPositions[i + 2] += 0.5;
            if (dustPositions[i + 2] > 100) {
                dustPositions[i + 2] = -1500;
            }
        }
        dustGeometry.attributes.position.needsUpdate = true;

        // ===== GALAXY ROTATION =====
        galaxies.forEach(galaxy => {
            galaxy.mesh.rotation.z += galaxy.rotationSpeed;
        });

        // ===== UFO ANIMATION =====
        ufos.forEach(ufo => {
            // Movement
            ufo.group.position.add(ufo.velocity);

            // Wobble effect
            ufo.wobble += ufo.wobbleSpeed;
            ufo.group.rotation.x = Math.sin(ufo.wobble) * 0.1;
            ufo.group.rotation.z = Math.cos(ufo.wobble * 0.7) * 0.15;
            ufo.group.rotation.y += 0.02; // Slow spin

            // Pulsing lights
            ufo.lightPhase += 0.1;
            ufo.lights.forEach((light, idx) => {
                light.material.opacity = 0.5 + Math.sin(ufo.lightPhase + idx * 0.8) * 0.5;
            });

            // Engine glow pulse
            ufo.engineMaterial.opacity = 0.3 + Math.sin(ufo.lightPhase * 2) * 0.2;

            // Reset position when out of view
            if (ufo.group.position.z > 300 ||
                Math.abs(ufo.group.position.x) > 1500 ||
                Math.abs(ufo.group.position.y) > 1000) {
                ufo.group.position.set(
                    (Math.random() - 0.5) * 2000,
                    (Math.random() - 0.5) * 1000,
                    -1500 - Math.random() * 500
                );
                ufo.velocity.set(
                    (Math.random() - 0.5) * 3,
                    (Math.random() - 0.5) * 1,
                    Math.random() * 2 + 1
                );
            }
        });

        // ===== SHOOTING STAR ANIMATION =====
        shootingStars.forEach(star => {
            if (!star.active) {
                star.cooldown--;
                if (star.cooldown <= 0) {
                    activateShootingStar(star);
                }
                return;
            }

            // Update position
            star.position.add(star.velocity);
            star.trail.unshift(star.position.clone());

            if (star.trail.length > star.trailLength) {
                star.trail.pop();
            }

            // Update geometry
            const positions = star.geometry.attributes.position.array;
            const colors = star.geometry.attributes.color.array;

            for (let i = 0; i < star.trailLength; i++) {
                if (i < star.trail.length) {
                    positions[i * 3] = star.trail[i].x;
                    positions[i * 3 + 1] = star.trail[i].y;
                    positions[i * 3 + 2] = star.trail[i].z;

                    const fade = 1 - (i / star.trailLength);
                    colors[i * 3] = fade;
                    colors[i * 3 + 1] = fade * 0.8;
                    colors[i * 3 + 2] = fade * 0.5;
                }
            }

            star.geometry.attributes.position.needsUpdate = true;
            star.geometry.attributes.color.needsUpdate = true;

            // Deactivate when out of view
            if (star.position.y < -1000 || star.position.z > 500) {
                star.active = false;
                star.cooldown = 100 + Math.random() * 300;
                star.trail = [];
            }
        });

        // ===== HYPERSPACE STREAKS =====
        hyperspaceStreaks.forEach(streak => {
            if (streak.active) {
                streak.z += streak.speed;
                streak.material.opacity = Math.min(0.6, (streak.z + 2000) / 1000);

                const positions = streak.geometry.attributes.position.array;
                positions[0] = streak.x;
                positions[1] = streak.y;
                positions[2] = streak.z;
                positions[3] = streak.x * 0.98;
                positions[4] = streak.y * 0.98;
                positions[5] = streak.z - streak.speed * 3;

                streak.geometry.attributes.position.needsUpdate = true;

                if (streak.z > 200) {
                    streak.z = -2000 - Math.random() * 500;
                    streak.x = (Math.random() - 0.5) * 1500;
                    streak.y = (Math.random() - 0.5) * 1500;
                    streak.active = Math.random() < 0.3;
                    streak.material.opacity = 0;
                }
            } else if (Math.random() < 0.002) {
                streak.active = true;
            }
        });

        // ===== GLOBAL ROTATION =====
        const rotationSpeed = isMobile ? 0.0001 : 0.0002;
        stars.rotation.y += rotationSpeed;
        dust.rotation.y += rotationSpeed * 0.5;

        renderer.render(scene, camera);
    }

    animate();

    // Handle window resize
    window.addEventListener('resize', () => {
        camera.aspect = window.innerWidth / window.innerHeight;
        camera.updateProjectionMatrix();
        renderer.setSize(window.innerWidth, window.innerHeight);
    });

})();
