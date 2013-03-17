BaseViewModel = require 'libs/base_view_model'
Synchronizer  = require 'libs/synchronizer'
ko            = require 'ko'

MID_SHIFT_PART     = .1
CROSS_ACCURACY     = .1  # [unit]
DELTA_PART         = .07
DIST_FACTOR        = 1.3
TIP_OFFSET         = 15
MULTIPLICITY_DIST  = 12  # [unit]
MULTIPLICITY_ANGLE = 35  # [°]
PATH_ID_PREFIX     = '__path__id__'

class RelationshipViewModel extends BaseViewModel
	freeID = 0

	constructor : (@sync) ->
		@type             = sync.observer 'type'
		@fromEssential    = sync.observer 'fromEssential'
		@toEssential      = sync.observer 'toEssential'
		@fromMultiplicity = sync.observer 'fromMultiplicity'
		@toMultiplicity   = sync.observer 'toMultiplicity'
		@fromIndicator    = sync.observer 'fromIndicator'
		@toIndicator      = sync.observer 'toIndicator'
		@level            = sync.observer 'level'
		@maxLevel         = sync.observer 'maxLevel'
		
		@isChosen    = ko.observable no
		@pathID      = "#{PATH_ID_PREFIX}#{freeID++}"
		@pathElement = ko.observable null

		super

		@isClassLevel.subscribe (value) =>
			if value
				@fromMultiplicity ''
				@toMultiplicity ''
				@fromIndicator ''
				@toIndicator ''

	@computed \
	isClassLevel : ->
		@type() in ['generalization', 'realization']

	@computed \
	isItself : ->
		@fromEssential() == @toEssential()

	@computed \
	shiftPart : ->
		2 * @level() / (@maxLevel() + 1) - 1

	@computed \
	placeFactor : ->
		if @fromEssential.deref().centerX() > @toEssential.deref().centerX()
			-1
		else
			1

	@computed \
	fromX : ->
		from = @fromEssential.deref()
		from.centerX() + (@level() && from.width()/2 * @shiftPart())

	@computed \
	fromY : ->
		from = @fromEssential.deref()
		if @isItself()
			from.posY() + from.height() * 4/5
		else
			from.centerY() + (@level() && from.height()/2 * @shiftPart())

	@computed \
	midX : ->
		if @isItself()
			@fromX() + @fromEssential.deref().width() * 2
		else
			fromPosX = @fromX()
			toPosX   = @toX()
			level    = @level()

			if level == 0 || @shiftPart() * @placeFactor() < 0
				fromPosX + (toPosX - fromPosX) * MID_SHIFT_PART
			else
				toPosX - (toPosX - fromPosX) * MID_SHIFT_PART

	@computed \
	midY : ->
		fromPosY = @fromY()
		toPosY   = @toY()
		level    = @level()
		if level == 0 || @shiftPart() * @placeFactor() < 0
			toPosY - (toPosY - fromPosY) * MID_SHIFT_PART
		else
			fromPosY + (toPosY - fromPosY) * MID_SHIFT_PART

	@computed \
	toX : ->
		to = @toEssential.deref()
		to.centerX() + (@level() && to.width()/2 * @shiftPart())

	@computed \
	toY : ->
		to = @toEssential.deref()
		if @isItself()
			to.posY() + to.height() / 5
		else
			to.centerY() + (@level() && to.height()/2 * @shiftPart())

	@computed \
	path : ->
		"""M #{@fromX()} #{@fromY()} Q
			#{@midX()}, #{@midY()}
		#{@toX()} #{@toY()}"""

	@computed \
	reversedPath : ->
		"""M #{@toX()} #{@toY()} Q
			#{@midX()}, #{@midY()}
		#{@fromX()} #{@fromY()}"""

	calcPart = (A, B, C, D) ->
		d = -A + 2*B - C
		if d == 0
			if A != B
				(A - D) / (2 * (A - B))
			else null
		else
			r = (-A*C + A*D + B*B - 2*B*D + C*D).sqrt()
			t = (r - A + B) / d
			unless 0 <= t <= 1
				t = (-r - A + B) / d

			if 0 <= t <= 1 then t else null

	calcPartAtX : (x) ->
		calcPart(@fromX(), @midX(), @toX(), x)

	calcPartAtY : (y) ->
		calcPart(@fromY(), @midY(), @toY(), y)

	calcPartFor : (ess) ->
		eWidth  = ess.width()
		eHeight = ess.height()
		ePosX   = ess.posX()
		ePosY   = ess.posY()

		part = @calcPartAtX(ePosX) ? @calcPartAtX(ePosX + eWidth)
		if part?
			y = @calcY part
			if ePosY - CROSS_ACCURACY < y < ePosY + eHeight + CROSS_ACCURACY
				return part

		part = @calcPartAtY(ePosY) ? @calcPartAtY(ePosY + eHeight)
		if part?
			x = @calcX part
			if ePosX - CROSS_ACCURACY < x < ePosX + eWidth + CROSS_ACCURACY
				return part

	@computed \
	fromCrossPart : ->
		@calcPartFor(@fromEssential.deref()) ? 0

	@computed \
	toCrossPart : ->
		@calcPartFor(@toEssential.deref()) ? 1

	calcX : (p) ->
		r = 1 - p
		r * r * @fromX() + 2 * p * r * @midX() + p * p * @toX()

	calcY : (p) ->
		r = 1 - p
		r * r * @fromY() + 2 * p * r * @midY() + p * p * @toY()

	calcTangentAngle : (part) ->
		if part + DELTA_PART > 1
			helpPart = 1
			part = 1 - DELTA_PART
		else
			helpPart = part + DELTA_PART

		Math.atan2(
			@calcY(helpPart) - @calcY(part), @calcX(helpPart) - @calcX(part)
		).toDegree()

	@computed \
	fromCrossAngle : ->
		@calcTangentAngle @fromCrossPart()

	@computed \
	toCrossAngle : ->
		@calcTangentAngle @toCrossPart()

	@computed \
	fromCrossX : ->
		@calcX @fromCrossPart()

	@computed \
	fromCrossY : ->
		@calcY @fromCrossPart()

	@computed \
	fromIsThick : ->
		@type() in ['aggregation', 'composition']

	@computed \
	toIsThick : ->
		!@fromIsThick()

	@computed \
	toCrossX : ->
		@calcX @toCrossPart()

	@computed \
	toCrossY : ->
		@calcY @toCrossPart()

	@computed \
	tipTransform : ->
		if @fromIsThick() && !@isItself()
			"translate(#{@fromCrossX()}, #{@fromCrossY()})" +
			"rotate(#{@fromCrossAngle() - 180})"
		else
			"translate(#{@toCrossX()}, #{@toCrossY()})" +
			"rotate(#{@toCrossAngle()})"

	calcMultiplicityAngle : (startAngle, indicator) ->
		s = if indicator.length == 0
			if 90 < startAngle < 180 || -90 < startAngle < 0 then -1 else 1
		else if @pathMode() == 'def' then 1 else -1
	
		(startAngle - 180 + s * MULTIPLICITY_ANGLE).toRadian()

	@computed \
	fromMultiplicityDist : ->
		dist = MULTIPLICITY_DIST
		if @fromIsThick()
			dist *= DIST_FACTOR
		if @fromMultiplicity().length > 1
			dist *= DIST_FACTOR
		if @fromIndicator().length > 0
			dist *= DIST_FACTOR
			
		dist

	@computed \
	toMultiplicityDist : ->
		dist = MULTIPLICITY_DIST
		if @toIsThick()
			dist *= DIST_FACTOR
		if @toMultiplicity().length > 1
			dist *= DIST_FACTOR
		if @toIndicator().length > 0
			dist *= DIST_FACTOR

		dist

	@computed \
	fromMultiplicityAngle : ->
		@calcMultiplicityAngle @fromCrossAngle(), @fromIndicator()

	@computed \
	toMultiplicityAngle : ->
		@calcMultiplicityAngle @toCrossAngle() + 180, @toIndicator()
		
	@computed \
	fromMultiplicityX : ->
		@fromCrossX() - @fromMultiplicityDist() * @fromMultiplicityAngle().cos()

	@computed \
	fromMultiplicityY : ->
		@fromCrossY() - @fromMultiplicityDist() * @fromMultiplicityAngle().sin()

	@computed \
	toMultiplicityX : ->
		@toCrossX() - @toMultiplicityDist() * @toMultiplicityAngle().cos()

	@computed \
	toMultiplicityY : ->
		@toCrossY() - @toMultiplicityDist() * @toMultiplicityAngle().sin()

	@computed \
	pathMode : ->
		if -90 < @fromCrossAngle() < 90 then 'def' else 'rev'

	@computed \
	pathLength : ->
		@fromX(); @fromY(); @toX(); @toY()
		@pathElement().getTotalLength()

	@computed \
	fromOffset : ->
		dist = ((@fromX() - @fromCrossX()).sqr() +
			(@fromY() - @fromCrossY()).sqr()).sqrt()

		dist += if @fromIsThick() then TIP_OFFSET else TIP_OFFSET / 3

		if @pathMode() == 'rev'
			@pathLength() - dist
		else dist
	
	@computed \
	toOffset : ->
		dist = ((@toX() - @toCrossX()).sqr() +
			(@toY() - @toCrossY()).sqr()).sqrt()

		dist += if @toIsThick() then TIP_OFFSET else TIP_OFFSET / 3

		if @pathMode() == 'def'
			@pathLength() - dist
		else dist

module.exports = RelationshipViewModel