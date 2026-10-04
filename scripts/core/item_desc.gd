class_name ItemDesc
## Descripciones breves de la tienda: una frase de ambientación y uso para cada objeto.

const SHIPS := {
	"kestrel_a1": "Caza de entrenamiento de la flota: ligero, rápido y perdonador con los errores del novato.",
	"raptor_v2": "Evolución agresiva del Kestrel con más bocas de fuego para cazar en solitario.",
	"needle_s": "Aguja de reconocimiento: la nave más veloz del hangar, a cambio de un casco de papel.",
	"falcon_r": "Caza equilibrado de élite; el favorito de los pilotos que lo quieren todo en una nave.",
	"bulwark_t1": "Muro volante pensado para aguantar el fuego mientras el escuadrón hace el trabajo.",
	"bastion_h": "Tanque con generadores de escudo de alto rendimiento para resistir oleadas largas.",
	"mammoth_k": "Fortaleza acorazada con ariete: casi nada la derriba, aunque gira como un asteroide.",
	"aegis_r": "Tanque ofensivo: blindaje pesado sin renunciar a una batería de láseres respetable.",
	"mule_c1": "Carguera de faena para las primeras expediciones de minería; barata y espaciosa.",
	"atlas_c4": "Contenedores apilados hasta el techo: lleva todo lo que el sector suelte.",
	"nomad_c": "Carguera ágil para recolectar entre combates sin quedarse atrás.",
	"prospector_ix": "Plataforma minera definitiva con la mayor bodega de la flota.",
	"vanguard_m": "Crucero versátil que abre la puerta a los sectores medios con solvencia.",
	"centurion_p": "Crucero de asalto: más láseres y más daño para limpiar sectores deprisa.",
	"orion_m7": "Crucero de apoyo con la mejor combinación de ranuras para configuraciones mixtas.",
	"helios_d": "Crucero de cristal y fuego: golpea muy fuerte, pero hay que cuidarlo.",
	"titan_b1": "Primer crucero de batalla: potencia bruta para los biomas del final del juego.",
	"imperator_vx": "Batería flotante con catorce láseres; su sola presencia vacía el radar.",
	"leviathan_k": "El casco más grueso jamás construido; diseñado para sobrevivir a todo.",
	"nova_rex": "Crucero de batalla de daño extremo para pilotos que prefieren atacar primero.",
	"specter_x": "Prototipo furtivo capaz de volverse intangible un instante para esquivar lo inevitable.",
	"fortress_omega": "Bastión especial que ancla su posición y multiplica su escudo bajo presión.",
	"ark_meridian": "Carguera especial con compresor de botín: absorbe todo lo que hay alrededor.",
	"seraph_prime": "Crucero prismático que sobrecarga sus láseres para ráfagas de cadencia altísima.",
	"event_horizon": "La cumbre de la flota: genera un pozo gravitacional que atrae y frena al enemigo.",
}
const LASERS := {
	"l01": "El láser estándar de la flota: sencillo, barato y fiable.",
	"l02": "Doble emisor paralelo; reparte el daño en dos haces más finos.",
	"l03": "Aguja prismática que atraviesa parte de la armadura enemiga.",
	"l04": "Ritmo de cadencia: cada cuarto disparo libera una descarga doble.",
	"l05": "Lanza iónica para derribar escudos antes de que se recarguen.",
	"l06": "Haz incendiario que deja al blanco ardiendo durante varios segundos.",
	"l07": "Rayo criogénico que congela los motores del enemigo y lo frena.",
	"l08": "Prisma dispersor: cinco rayos en abanico para enjambres cercanos.",
	"l09": "Arco eléctrico que salta entre enemigos agrupados.",
	"l10": "Láser de asedio lento y devastador contra objetivos grandes.",
	"l11": "Cortador de fase que a veces ignora el escudo y daña el casco directamente.",
	"l12": "Resonancia: cuanto más tiempo dispara al mismo blanco, más daño hace.",
	"l13": "Lanza solar que perfora varias naves en línea.",
	"l14": "Rayo nulo que debilita al enemigo y reduce el daño que inflige.",
	"l15": "Haz de singularidad que arrastra ligeramente a su objetivo.",
	"l16": "Eco cuántico: a veces el disparo se repite gratis.",
	"l17": "Tres haces que convergen en un único punto de impacto.",
	"l18": "Láser de olvido: cada diez impactos provoca una explosión triple.",
}
const GENS := {
	"sg_aegis1": "Generador de escudo básico, sin penalizaciones.",
	"sg_aegis2": "Escudo mejorado a costa de un poco de masa.",
	"sg_flux": "Escudo de flujo que se recarga más rápido sacrificando algo de casco.",
	"sg_bulwark": "Escudo pesado para tanques que no necesitan correr.",
	"sg_pulse": "Al romperse lanza una onda que aparta a los enemigos.",
	"sg_reflect": "Puede devolver proyectiles ligeros a quien los disparó.",
	"sg_repair": "Regenera el escudo poco a poco cuando no recibes daño.",
	"sg_null": "Acorta los efectos que te aplican los enemigos.",
	"sg_fortress": "El escudo más grueso, para naves que viven en primera línea.",
	"sg_quantum": "A veces reduce un impacto fuerte en un tercio.",
	"vg_thrust1": "Impulsor básico de velocidad, sin penalizaciones.",
	"vg_thrust2": "Más velocidad a cambio de un poco de escudo.",
	"vg_vector": "Toberas vectoriales: mejor aceleración en los giros.",
	"vg_blink": "Recarga el impulso antes para esquivar más a menudo.",
	"vg_racer": "Motor de carreras: muy rápido y con poco escudo.",
	"vg_inertia": "Amortiguadores de inercia para un control de giro preciso.",
	"vg_overdrive": "Tras cada impulso da un empujón extra de velocidad.",
	"vg_phase": "Puede ignorar las ralentizaciones enemigas.",
	"vg_comet": "Velocidad de cometa a cambio de casco.",
	"vg_horizon": "Con poca vida, acelera de golpe para escapar.",
}
const AMMO := {
	"mk1": "Carga estándar de entrenamiento. Barata para limpiar enemigos comunes.",
	"mk2": "Doble potencia por disparo; la opción habitual contra élites.",
	"mk3": "Triple potencia. Atraviesa mejor los escudos blindados.",
	"mk4": "Carga pesada para jefes y variantes Mega.",
	"mk5": "Munición de alto rendimiento; sólo se fabrica.",
	"mk6": "La carga definitiva, reservada para lo imposible; sólo se fabrica.",
}
const MISSILES := {
	"r1": "Misil ligero de uso general: barato y suficiente para el día a día.",
	"r2": "Más carga explosiva en una cabeza afilada y algo más precisa.",
	"r3": "Gran cabeza explosiva; pesa más y falla un poco más.",
	"rt4": "Guiado de precisión: casi nunca falla, aunque el blanco se mueva.",
	"r5": "Cabeza de fragmentación que daña también a los enemigos cercanos.",
	"r6": "Carga singular de enorme potencia y gran radio de explosión.",
}
const ITEMS := {
	"repair": "Nanobots que sellan el casco en pleno combate.",
	"boost": "Inyección de combustible para escapar o perseguir.",
	"mine": "Mina de proximidad para cubrir una retirada o una emboscada.",
	"shield_cell": "Recarga de emergencia para el generador de escudo.",
}
const PET_LASERS := {
	"pet_pulse": "Láser estándar del pet, estable y sin complicaciones.",
	"pet_stinger": "Cada cinco impactos clava un golpe doble.",
	"pet_ion": "Especialista en derribar escudos enemigos.",
	"pet_arc": "Su descarga puede saltar a un segundo enemigo.",
	"pet_guard": "Daña poco, pero derriba proyectiles que vienen hacia tu nave.",
	"pet_marker": "Marca al enemigo para que tu nave le haga más daño.",
}
const PET := "Compañero robótico que te escolta, dispara a tu objetivo o recoge botín, y evoluciona al subir de nivel."


static func of(kind: String, id: String) -> String:
	match kind:
		"ship":
			return SHIPS.get(id, "")
		"laser":
			return LASERS.get(id, "")
		"gen":
			return GENS.get(id, "")
		"ammo":
			return AMMO.get(id, "")
		"missile":
			return MISSILES.get(id, "")
		"item":
			return ITEMS.get(id, "")
		"drone_laser":
			return PET_LASERS.get(id, "")
		"pet":
			return PET
	return ""
