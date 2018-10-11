from __future__ import print_function

'''Python script intended to be passed to PSyclone's generate()
function via the -s option. Performs OpenACC transformations. '''


def trans(psy):
    ''' Take the supplied psy object, apply OpenACC transformations
    to the schedule of invoke_0 and return the new psy object '''
    from psyclone.transformations import ACCParallelTrans, \
        ACCDataTrans, ACCLoopTrans, ACCRoutineTrans
    ptrans = ACCParallelTrans()
    ltrans = ACCLoopTrans()
    dtrans = ACCDataTrans()
    ktrans = ACCRoutineTrans()

    invoke = psy.invokes.get('invoke_0')
    schedule = invoke.schedule
    # schedule.view()

    # Apply the OpenACC Loop transformation to *every* loop
    # nest in the schedule
    from psyclone.psyGen import Loop
    for child in schedule.children:
        if isinstance(child, Loop):
            newschedule, _ = ltrans.apply(child, collapse=2)
            schedule = newschedule

    # Put all of the loops in a single parallel region
    newschedule, _ = ptrans.apply(schedule.children)

    # Add an enter-data directive
    newschedule, _ = dtrans.apply(schedule)

    # Put an 'acc routine' directive inside each kernel
    for kern in schedule.kern_calls():
        _, _ = ktrans.apply(kern)

    invoke.schedule = newschedule
    newschedule.view()
    return psy


if __name__ == "__main__":
    from psyclone.parse import parse
    from psyclone.psyGen import PSyFactory
    API = "gocean1.0"
    FILENAME = "nemolite2d_alg.f90"
    _, INVOKEINFO = parse(FILENAME,
                          api=API,
                          invoke_name="invoke")
    PSY = PSyFactory(API).create(INVOKEINFO)
    # print(PSY.invokes.names)

    NEW_PSY = trans(PSY)

    print(NEW_PSY.gen)
