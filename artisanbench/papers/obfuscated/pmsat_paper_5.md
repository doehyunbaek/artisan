# **It’s Not a Feature, It’s a Bug:** **Fault-Tolerant Model Mining from Noisy Data**



Felix Wallner

felix.wallner@ist.tugraz.at
Graz University of Technology
Graz, Austria


**ABSTRACT**



Bernhard K. Aichernig
aichernig@ist.tugraz.at
Graz University of Technology
Graz, Austria



Christian Burghard
christian.burghard@avl.com
AVL List GmbH

Graz, Austria



The mining of models from data finds widespread use in industry.
There exists a variety of model inference methods for perfectly deterministic behaviour, however, in practice, the provided data often
contains noise due to faults such as message loss or environmental
factors that many of the inference algorithms have problems dealing with. We present a novel model mining approach using Partial
Max-SAT solving to infer the best possible automaton from a set
of noisy execution traces. This approach enables us to ignore the
minimal number of presumably faulty observations to allow the
construction of a deterministic automaton. No pre-processing of
the data is required. The method’s performance as well as a number
of considerations for practical use are evaluated, including three
industrial use cases, for which we inferred the correct models.


**CCS CONCEPTS**


- **Theory of computation** → **Logic and verification** ; **Formal**
**languages and automata theory** .


**KEYWORDS**


Automata Learning, SAT solving, Partial Max-SAT, Model Inference,

Non-Determinism


**ACM Reference Format:**

Felix Wallner, Bernhard K. Aichernig, and Christian Burghard. 2024. It’s
Not a Feature, It’s a Bug: Fault-Tolerant Model Mining from Noisy Data. In
_2024 IEEE/ACM 46th International Conference on Software Engineering (ICSE_
_’24), April 14–20, 2024, Lisbon, Portugal._ ACM, New York, NY, USA, 13 pages.
[https://doi.org/10.1145/3597503.3623346](https://doi.org/10.1145/3597503.3623346)


**1** **INTRODUCTION**


The problem of inferring Finite State Machines (FSMs) from a set of
execution traces is well known: Originally proposed by Biermann
and Feldman [ 9 ] as a constraint satisfaction problem (CSP) and
then as a Boolean satisfiability problem (SAT) by Grinchtein et
al. [ 17 ], which was further improved by others [ 5, 19 ], mining
behavioural models from data is a well-researched topic [ 39 ]. Such
models may be used for model-based development, verification
and monitoring among other purposes in industry. In practice,
however, the data that is used for behavioural model inference is


[This work is licensed under a Creative Commons Attribution International 4.0 License.](https://creativecommons.org/licenses/by/4.0/)


_ICSE ’24, April 14–20, 2024, Lisbon, Portugal_
© 2024 Copyright held by the owner/author(s).
ACM ISBN 979-8-4007-0217-4/24/04.
[https://doi.org/10.1145/3597503.3623346](https://doi.org/10.1145/3597503.3623346)



often not perfectly deterministic. Faults such as message loss or
other environmental influences, which may not be immediately
apparent, may introduce noise into the data. This prevents many
other deterministic inference methods, such as RPNI [ 41 ], from
mining models from said data. Other approaches exist to learn
stochastic [ 30 ] or non-deterministic automata [ 51 ], however, these
methods encode the noise directly into the automata, which is often
not desired, especially if it is known in advance that the underlying
system is deterministic. In fact, one of the requirements from our
industrial partner is to ignore or filter out the noise to learn the
underlying FSM. At this point one has to either give up or perform
preprocessing on the data, which may require domain knowledge.
In this paper, we present a novel approach to mine behavioural
models from noisy data by ignoring the _least amount of steps neces-_
_sary_ in order to make it deterministic. The approach is such that no
preprocessing regarding the noise is necessary. The assumptions
about our underlying system are that it is deterministic and that
faults appear sporadically and randomly, i.e., not systematically,
with equal likelihood at any point in our data. The most typical
noise with such properties is message loss, which we focus on
during benchmarks by dropping input-output pairs from traces.
Additionally, it is possible to mine a model from a single long
execution trace instead of multiple samples. While other approaches
can work with single traces [ 18 ] they usually cannot deal with noise
in the data. Two of our use cases demonstrate the use of our method

on such single trace cases of industrial measurement devices.
Finally, our approach may also be used to extract a type of stochastic automaton, which includes the noise and the frequencies
of the transitions used, as an addition to the fully deterministic
models in order to better evaluate the types and amount of noise
in the input data.
The research questions we want to answer are:


RQ 1: Is it possible to mine models from noisy data using Partial
Max-SAT?

RQ 2: Which considerations have to be taken into account when
applying the method in practice?
RQ 3: How performant is such an approach?


After presenting the preliminaries in Section 2, we answer these
questions by means of the following contributions: (1) We present
a novel approach to infer models from noisy data using Partial
Max-SAT (Section 3). (2) We further present guidelines on how
this method can be used in practice (Section 4). (3) We evaluate
the method’s performance (Section 5). The experiments show that
despite the well-known complexity limitations of (Partial) MaxSAT, i.e., the problem being NP-hard [ 25 ], we were able to mine
three relevant industrial models from measurement devices and

communication protocols, as well as benchmark models of sizes


ICSE ’24, April 14–20, 2024, Lisbon, Portugal Felix Wallner, Bernhard K. Aichernig, and Christian Burghard



up to 17 states and traces up to 6000 steps in length within several
minutes. Longer traces or more states quickly lead to timeouts after
one hour.


**2** **PARTIAL MAX-SAT FOR MOORE MACHINES**

**2.1** **Moore Machines**


Our algorithm assumes that the system we want to learn is deterministic and can be modelled as a Moore machine, as first described
by Moore [ 33 ]. These are a type of FSM which can classically be
defined as a 6-tuple, where the Moore machine M is:


M = ( _𝐼,𝑂,𝑆,𝑠_ 0 _,𝛿_ M _, 𝜆_ M )

where _𝐼_, _𝑂_ and _𝑆_ are the finite, non-empty sets of input symbols,
output symbols and states, respectively, _𝑠_ 0 ∈ _𝑆_ is the initial state
and _𝛿_ M : _𝑆_ × _𝐼_ → _𝑆_ and _𝜆_ M : _𝑆_ → _𝑂_ are the state transition
and the output function, respectively. Importantly, the output function depends solely on the current state of the machine. A Moore
machine is _input-complete_ if _𝛿_ M is fully defined.
We define a _trace_ _𝑡_ to be _𝑡_ = ⟨ _𝑜_ 0 _,_ ( _𝑖_ 1 _,𝑜_ 1 ) _,_ ( _𝑖_ 2 _,𝑜_ 2 ) _, . . .,_ ( _𝑖_ _𝑚_ _,𝑜_ _𝑚_ )⟩
with _𝑜_ _𝑗_ ∈ _𝑂_ and _𝑖_ _𝑗_ ∈ _𝐼_ . Note that the index of each trace starts with
0, as the first element of the trace is the initial output _𝑜_ 0, which is the
output of the initial state _𝑠_ 0, followed by _𝑚_ steps, i.e., input-output
pairs, hence the length of the trace | _𝑡_ | = _𝑚_ + 1. For a given index
_𝑘_ ∈[ 1 _,𝑚_ ] we will write _𝑖_ _𝑘_ and _𝑜_ _𝑘_ for the _𝑘_ _[𝑡ℎ]_ input and output of a
trace, respectively.
Additionally, we define a _non-deterministic_ Moore machine to
use a transition relation _𝛿_ M : _𝑆_ × _𝐼_ × _𝑆_ instead of a function. If the
transitions of a non-deterministic Moore machine are also labelled

with their occurrence frequencies or probabilities, we obtain a
_stochastic_ Moore machine. Note that the latter corresponds to a
Markov-decision process.


**2.2** **Partial Max-SAT**


The aim of traditional SAT solving is to find an assignment of
variables for a given set of clauses in conjunctive normal form
(CNF) such that the formula becomes true, i.e., satisfiable, or to
find that such an assignment does not exists, i.e., the formula is
unsatisfiable. Partial Max-SAT (PMSAT) is a mixture of the SAT
and Max-SAT problems, insofar as a PMSAT problem consists of
two sets of clauses: one which has to be satisfied using SAT and
one for which the number of fulfilled clauses has to be _maximised_
using Max-SAT. The clauses in the former set are called _hard clauses_
while the ones in the latter are called _soft clauses_ . Solving a PMSAT
problem comes down to finding an assignment that satisfies the
maximum number of soft clauses while also satisfying all hard
clauses [4, 14].


_Quantifiers._ To more concisely describe the multitude of clauses
necessary to build the PMSAT problem we use quantifiers. We
resolve all quantifiers through enumeration such that ∀ _𝑥_ ∈ _𝑋_ :
P( _𝑥_ ) corresponds to the CNF formula P( _𝑥_ 1 ) ∧P ( _𝑥_ 2 ) ∧ _. . ._ ∧P( _𝑥_ _𝑛_ ),
where each P( _𝑥_ _𝑗_ ) is a propositional variable and P( _𝑥_ _𝑗_ ) its negation.



_Exactly One._ We define ∃ ! _𝑥_ ∈ _𝑋_ : P( _𝑥_ ) to mean that we require
exactly one of the _𝑛_ variables {P( _𝑥_ ) : _𝑥_ ∈ _𝑋_ } to be true, which will
result in the following clauses: (P( _𝑥_ 1 ) ∨P( _𝑥_ 2 ) ∨ _. . ._ ∨P( _𝑥_ _𝑛_ )) to require at least one variable to be true and ∀ _𝑖_ ∈[ 1 _,𝑛_ − 1 ] _,_ ∀ _𝑗_ ∈[ _𝑖_ + 1 _,𝑛_ ] :
(P( _𝑥_ _𝑖_ ) ∨P( _𝑥_ _𝑗_ )) to prevent any pair-wise combination of variables
to be true at the same time. For example, ∃ ! _𝑥_ ∈ { _𝑥_ 1 _,𝑥_ 2 _,𝑥_ 3 } : P( _𝑥_ )
would result in (P( _𝑥_ 1 ) ∨P( _𝑥_ 2 ) ∨P( _𝑥_ 3 )) ∧(P( _𝑥_ 1 ) ∨P( _𝑥_ 2 )) ∧
(P( _𝑥_ 1 ) ∨P( _𝑥_ 3 )) ∧(P( _𝑥_ 2 ) ∨P( _𝑥_ 3 )).


**3** **MODEL MINING WITH PARTIAL MAX-SAT**

**3.1** **Variables**


We define the following four classes of Boolean variables used by
the solver in order to more clearly describe their meanings. Each
instance of these terms corresponds to a single variable in the solver
that can either be true or false:


  - _𝜆_ ( _𝑠,𝑜_ ) is true iff state _𝑠_ has output _𝑜_ .

  - _𝛿_ ( _𝑠,𝑖,𝑠_ [′] ) is true iff state _𝑠_ transitions to state _𝑠_ [′] on input _𝑖_ .

  - _𝜔_ ( _𝑡,𝑘,𝑠_ ) is true iff the post-state after _𝑘_ steps in trace _𝑡_
corresponds to _𝑠_ .

  - G( _𝑡,𝑘_ ) is true iff step _𝑘_ of trace _𝑡_ is considered a _glitch_, i.e.,
does not conform to the deterministic transition function.


For readability purposes we use these terms directly in place
of Boolean variables. For example, _𝜆_ ( _𝑠_ [′] _,_ acknowledge) = _true_ would
mean that the state _𝑠_ [′] has output ‘acknowledge’. _𝛿_ ( _𝑠_ _𝑥_ _,_ connect _,𝑠_ _𝑦_ ) =
_false_ would mean that there exists no transition from state _𝑠_ _𝑥_ with
input ‘connect’ to state _𝑠_ _𝑦_ . A formula to describe that the output of a
single state _𝑠_ [′] should be either _𝑎_ or _𝑏_ would be: ( _𝜆_ ( _𝑠_ [′] _,𝑎_ )∨ _𝜆_ ( _𝑠_ [′] _,𝑏_ ))∧
( _𝜆_ ( _𝑠_ [′] _,𝑎_ ) ∨ _𝜆_ ( _𝑠_ [′] _,𝑏_ )), which would be equivalent to _𝜆_ ( _𝑠_ [′] _,𝑎_ ) ⊕ _𝜆_ ( _𝑠_ [′] _,𝑏_ ) .


**3.2** **SAT Formalisation**


Let _𝑆_ = { _𝑠_ 0 _,𝑠_ 1 _, . . .,𝑠_ _𝑛_ −1 } be a set of _𝑛_ states and _𝑇_ a set of traces
over our inputs _𝐼_ and outputs _𝑂_ . For the given sets _𝑆, 𝐼,𝑂_ and _𝑇_, we
may now build our SAT problem in the form of a CNF such that
its assignment will correspond to an automaton with _𝑛_ states that
produces the given traces with the minimum number of glitches
possible:
Each state of a valid automaton must have exactly one output:


∀ _𝑠_ ∈ _𝑆_ : ∃! _𝑜_ ∈ _𝑂_ : _𝜆_ ( _𝑠,𝑜_ ) (1)


Every state must have a single deterministic transition on each
state-input pair:


∀ _𝑠_ ∈ _𝑆_ : ∀ _𝑖_ ∈ _𝐼_ : ∃! _𝑠_ [′] ∈ _𝑆_ : _𝛿_ ( _𝑠,𝑖,𝑠_ [′] ) (2)


and after each step in a trace the automaton must be in exactly

one state:


∀ _𝑡_ ∈ _𝑇_ : ∀ _𝑘_ ∈[0 _,_ | _𝑡_ |) : ∃! _𝑠_ ∈ _𝑆_ : _𝜔_ ( _𝑡,𝑘,𝑠_ ) (3)


Each output _𝑜_ _𝑘_ corresponds to the reached state _𝑠_ of that given
step in the trace:


∀ _𝑡_ ∈ _𝑇_ : ∀ _𝑘_ ∈[0 _,_ | _𝑡_ |) : ∀ _𝑠_ ∈ _𝑆_ : ( _𝜔_ ( _𝑡,𝑘,𝑠_ ) =⇒ _𝜆_ ( _𝑠,𝑜_ _𝑘_ )) (4)


and for each step in the trace the predecessor state must have
a valid transition to the successor state with the observed input.
Otherwise, the step is considered a glitch:


It’s Not a Feature, It’s a Bug ICSE ’24, April 14–20, 2024, Lisbon, Portugal


**Table 1: Summary of variables for inferring automata with**
**states** _**S**_ **from traces** _**T**_ **with inputs** _**I**_ **and outputs** _**O**_ **.**

∀ _𝑡_ ∈ _𝑇_ : ∀ _𝑘_ ∈[1 _,_ | _𝑡_ |) : ∀ _𝑠,𝑠_ [′] ∈ _𝑆_ : (5)



( _𝜔_ ( _𝑡,𝑘_ − 1 _,𝑠_ ) ∧ _𝜔_ ( _𝑡,𝑘,𝑠_ [′] ) =⇒ _𝛿_ ( _𝑠,𝑖_ _𝑘_ _,𝑠_ [′] ) ∨G( _𝑡,𝑘_ ))


Finally, we want every step to not be a glitch if possible, however,
we add this restriction as _soft clauses_ in order to allow solutions
even if we have too few states to explain the traces in full or in case
the traces contain real non-determinism:


∀ _𝑡_ ∈ _𝑇_ : ∀ _𝑘_ ∈[1 _,_ | _𝑡_ |) : **soft :** G( _𝑡,𝑘_ ) (6)


_Reliable Initial State._ The starting state of the given traces requires consideration. Usually, the initial state is the same over all
traces and the initial output observed in all traces is also the same.
This allows for an additional constraint: For each trace the first
output before the first step at index 0 corresponds to the output of
the initial state _𝑠_ 0 :


∀ _𝑡_ ∈ _𝑇_ : _𝜔_ ( _𝑡,_ 0 _,𝑠_ 0 ) (7)


However, if the initial state may differ between traces, i.e., we
cannot rely on starting in the same state, then this constraint can
be omitted, which will allow each trace to start at any state in the

automaton.


_Optimisation._ Finally, an important optimisation that improves
performance stems from the following consideration: If our set of
outputs _𝑂_ is built from the traces that contain our observations,
then each output must appear at least in one state in the final
automaton, otherwise we could not observe it. We may therefore
assign each of the first | _𝑂_ | states directly to one corresponding
output:


∀ _𝑝_ ∈[0 _,_ | _𝑂_ |) : _𝜆_ ( _𝑠_ _𝑝_ _,𝑜_ _𝑝_ ) (8)


Note that, in contrast to Equation 3, _𝑜_ _𝑝_ refers to the _𝑝_ -th output in _𝑂_ .
The indexing of _𝑂_ is mostly arbitrary, however, if the constraint in
Equation 7 is used, then the state _𝑠_ 0 must receive the corresponding
initial output _𝑜_ 0 from the beginning of the traces. This optimisation
strongly constrains the search space by preventing the assignment
of different state labels to the same combinations of outputs. For
example, instead of _𝜆_ ( _𝑠_ 0 _,𝑜_ 0 ) ∧ _𝜆_ ( _𝑠_ 1 _,𝑜_ 1 ) or _𝜆_ ( _𝑠_ 1 _,𝑜_ 0 ) ∧ _𝜆_ ( _𝑠_ 0 _,𝑜_ 1 ) only
the first assignment is considered when using the constraint. This
also makes assignment of outputs to states trivial in case of | _𝑂_ |
states, leaving only a single possible assignment. Increasing the
number of states still keeps the first | _𝑂_ | states fixed and allows for
flexible output assignments for the additional states.
Table 1 summarises the clauses.


_Number of Clauses and Variables._ We define _𝑡_ _𝑎𝑙𝑙_ = [�] _𝑡_ ∈ _𝑇_ [|] _[𝑡]_ [|] [ to]
be the total length of all traces and _𝑡_ _𝑠𝑡𝑒𝑝𝑠_ = _𝑡_ _𝑎𝑙𝑙_ −| _𝑇_ | to be the
total number of steps in the traces, which do not include the initial
state output of each trace. It can easily be seen from Equation 6
that the number of soft clauses is exactly _𝑡_ _𝑠𝑡𝑒𝑝𝑠_ . Because ∃ ! _𝑥_ ∈
_𝑋_ is enumerated with O(| _𝑋_ | [2] ) clauses, the total number of hard
clauses can be given an upper bound of O(| _𝑆_ | [3] | _𝐼_ |) for Equation 2
and O( _𝑡_ _𝑠𝑡𝑒𝑝𝑠_ | _𝑆_ | [2] ) for Equation 5 whereby the latter usually is the
defining one due to _𝑡_ _𝑠𝑡𝑒𝑝𝑠_ ≫| _𝑆_ | . The number of unique variables,
i.e., the sum of all unique _𝜆,𝛿,𝜔_ and G, can be counted to be | _𝑆_ | ×
| _𝑂_ | + | _𝑆_ | [2] × | _𝐼_ | + _𝑡_ _𝑎𝑙𝑙_ × | _𝑆_ | + _𝑡_ _𝑠𝑡𝑒𝑝𝑠_ .









|Eq.|Clauses|Enumeration|
|---|---|---|
|(1)|_𝜆_(_𝑠,𝑜_)|∀_𝑠_∈_𝑆_: ∃!_𝑜_∈_𝑂_|
|(2)|_𝛿_(_𝑠,𝑖,𝑠_′)|∀_𝑠_∈_𝑆_: ∀_𝑖_∈_𝐼_: ∃!_𝑠_′ ∈_𝑆_|
|(3)|_𝜔_(_𝑡,𝑘,𝑠_)|∀_𝑡_∈_𝑇_: ∀_𝑘_∈[0_,_ |_𝑡_|) : ∃!_𝑠_∈_𝑆_|
|(4)|_𝜔_(_𝑡,𝑘,𝑠_)<br>∨<br>_𝜆_(_𝑠,𝑜𝑘_))|∀_𝑡_∈_𝑇_: ∀_𝑘_∈[0_,_ |_𝑡_|) : ∀_𝑠_∈_𝑆_<br>|
|(5)|_𝜔_(_𝑡,𝑘_−1_,𝑠_) ∨<br>_𝜔_(_𝑡,𝑘,𝑠_′)<br>∨<br>_𝛿_(_𝑠,𝑖𝑘,𝑠_′)<br>∨<br>G(_𝑡,𝑘_)|∀_𝑡_∈_𝑇_: ∀_𝑘_∈[1_,_ |_𝑡_|) : ∀_𝑠,𝑠_′ ∈_𝑆_|
|(6)|**soft :** G(_𝑡,𝑘_)|∀_𝑡_∈_𝑇_: ∀_𝑘_∈[1_,_ |_𝑡_|)|
|(7)|_𝜔_(_𝑡,_ 0_,𝑠_0)|∀_𝑡_∈_𝑇_|
|(8)|_𝜆_(_𝑠𝑝,𝑜𝑝_)|∀_𝑝_∈[0_,_ |_𝑂_|) -_ 𝑜_0 initial output|


disconnect



disconnect



connect



**(a) Moore machine of simple example server**


connect



disconnect



connect



**(b) Inferred non-deterministic Moore machine**
**of simple example server with glitch**


**Figure 1: Moore machines of simple example server.**


**3.3** **Example**


By the following example, we want to demonstrate how a model
can be inferred from traces:

Given the Moore machine in Figure 1a with _𝐼_ = {connect _,_
disconnect } and _𝑂_ = {offline _,_ online} let us assume we generated
the following traces _𝑇_ = { _𝑡_ 0 _,𝑡_ 1 } with:
_𝑡_ 0 = ⟨offline _,_ (disconnect _,_ offline) _,_ (connect _,_ online)⟩ and
_𝑡_ 1 = ⟨offline _,_ (connect _,_ online) _,_ (connect _,_ online) _,_ ( disconnect, offline)⟩.
The given traces are representative, i.e., they contain enough
information to fully determine the original automaton. Also, we
must choose the number of states _𝑛_ for the automaton we want

to infer. For now, we choose the smallest possible _𝑛_ in this case,
namely _𝑛_ = | _𝑂_ | = 2 and build the following SAT problem for
_𝑆_ = { _𝑠_ 0 _,𝑠_ 1 } _, 𝐼,𝑂_ and _𝑇_ = { _𝑡_ 0 _,𝑡_ 1 } using the definitions from Table 1:


ICSE ’24, April 14–20, 2024, Lisbon, Portugal Felix Wallner, Bernhard K. Aichernig, and Christian Burghard



(1) ( _𝜆_ ( _𝑠_ 0 _,_ offline) ∨ _𝜆_ ( _𝑠_ 0 _,_ online)) ∧( _𝜆_ ( _𝑠_ 0 _,_ offline) ∨ _𝜆_ ( _𝑠_ 0 _,_ online))
∧( _𝜆_ ( _𝑠_ 1 _,_ offline) ∨ _𝜆_ ( _𝑠_ 1 _,_ online)) ∧( _𝜆_ ( _𝑠_ 1 _,_ offline) ∨ _𝜆_ ( _𝑠_ 1 _,_ online))
(2) ( _𝛿_ ( _𝑠_ 0 _,_ disconnect _,𝑠_ 0 ) ∨ _𝛿_ ( _𝑠_ 0 _,_ disconnect _,𝑠_ 1 )) ∧
( _𝛿_ ( _𝑠_ 0 _,_ disconnect _,𝑠_ 0 ) ∨ _𝛿_ ( _𝑠_ 0 _,_ disconnect _,𝑠_ 1 )) ∧
( _𝛿_ ( _𝑠_ 0 _,_ connect _,𝑠_ 0 ) ∨ _𝛿_ ( _𝑠_ 0 _,_ connect _,𝑠_ 1 )) ∧ _. . ._
(3) ( _𝜔_ ( _𝑡_ 0 _,_ 0 _,𝑠_ 0 ) ∨ _𝜔_ ( _𝑡_ 0 _,_ 0 _,𝑠_ 1 )) ∧( _𝜔_ ( _𝑡_ 0 _,_ 0 _,𝑠_ 0 ) ∨ _𝜔_ ( _𝑡_ 0 _,_ 0 _,𝑠_ 1 ))
∧ ( _𝜔_ ( _𝑡_ 0 _,_ 1 _,𝑠_ 0 ) ∨ _𝜔_ ( _𝑡_ 0 _,_ 1 _,𝑠_ 1 )) ∧( _𝜔_ ( _𝑡_ 0 _,_ 1 _,𝑠_ 0 ) ∨ _𝜔_ ( _𝑡_ 0 _,_ 1 _,𝑠_ 1 )) ∧ _. . ._
(4) ( _𝜔_ ( _𝑡_ 0 _,_ 0 _,𝑠_ 0 ) ∨ _𝜆_ ( _𝑠_ 0 _,_ offline)) ∧( _𝜔_ ( _𝑡_ 0 _,_ 0 _,𝑠_ 1 ) ∨ _𝜆_ ( _𝑠_ 1 _,_ offline)) ∧
( _𝜔_ ( _𝑡_ 0 _,_ 1 _,𝑠_ 0 ) ∨ _𝜆_ ( _𝑠_ 0 _,_ offline)) ∧( _𝜔_ ( _𝑡_ 0 _,_ 1 _,𝑠_ 1 ) ∨ _𝜆_ ( _𝑠_ 1 _,_ offline)) ∧
( _𝜔_ ( _𝑡_ 0 _,_ 2 _,𝑠_ 0 ) ∨ _𝜆_ ( _𝑠_ 0 _,_ online)) ∧( _𝜔_ ( _𝑡_ 0 _,_ 2 _,𝑠_ 1 ) ∨ _𝜆_ ( _𝑠_ 1 _,_ online)) _. . ._
(5) ( _𝜔_ ( _𝑡_ 0 _,_ 0 _,𝑠_ 0 ) ∨ _𝜔_ ( _𝑡_ 0 _,_ 0 _,𝑠_ 1 ) ∨ _𝛿_ ( _𝑠_ 0 _,_ disconnect _,𝑠_ 1 ) ∨G( _𝑡_ 0 _,_ 1 )) ∧
( _𝜔_ ( _𝑡_ 0 _,_ 0 _,𝑠_ 1 ) ∨ _𝜔_ ( _𝑡_ 0 _,_ 0 _,𝑠_ 2 ) ∨ _𝛿_ ( _𝑠_ 1 _,_ connect _,𝑠_ 2 ) ∨ G( _𝑡_ 0 _,_ 2)) ∧ _. . ._
(6) **soft:** G( _𝑡_ 0 _,_ 1) ∧G( _𝑡_ 0 _,_ 2) ∧G( _𝑡_ 1 _,_ 1) ∧G( _𝑡_ 1 _,_ 2) ∧G( _𝑡_ 1 _,_ 3)
(7) _𝜔_ ( _𝑡_ 0 _,_ 0 _,𝑠_ 0 ) ∧ _𝜔_ ( _𝑡_ 1 _,_ 0 _,𝑠_ 0 )
(8) _𝜆_ ( _𝑠_ 0 _,_ offline) ∧ _𝜆_ ( _𝑠_ 1 _,_ online)


Giving the above SAT problem to a PMSAT solver yields the
following solution, which contains all the variables assigned true by
the solver: _𝜆_ ( _𝑠_ 0 _,_ offline) ∧ _𝛿_ ( _𝑠_ 0 _,_ connect _,𝑠_ 1 ) ∧ _𝛿_ ( _𝑠_ 0 _,_ disconnect _,𝑠_ 0 ) ∧
_𝜆_ ( _𝑠_ 1 _,_ online)∧ _𝛿_ ( _𝑠_ 1 _,_ connect _,𝑠_ 1 )∧ _𝛿_ ( _𝑠_ 1 _,_ disconnect _,𝑠_ 0 )∧ _𝜔_ ( _𝑡_ 0 _,_ 0 _,𝑠_ 0 )∧
_𝜔_ ( _𝑡_ 0 _,_ 1 _,𝑠_ 0 ) ∧ _𝜔_ ( _𝑡_ 0 _,_ 2 _,𝑠_ 1 ) ∧ _𝜔_ ( _𝑡_ 1 _,_ 0 _,𝑠_ 0 ) ∧ _𝜔_ ( _𝑡_ 1 _,_ 1 _,𝑠_ 1 ) ∧ _𝜔_ ( _𝑡_ 1 _,_ 2 _,𝑠_ 1 ) ∧
_𝜔_ ( _𝑡_ 1 _,_ 3 _,𝑠_ 0 ).
Interpreting this solution as an automaton, by looking at the
assigned _𝜆_ state outputs and the _𝛿_ transitions, yields the automaton
in Figure 1a, which we correctly infer with zero glitches.


_Example with Glitches._ Now, let us assume we observe a third
trace _𝑡_ 2 = ⟨offline _,_ (disconnect _,_ offline) _,_ (connect _,_ offline)⟩.
This trace contains a step from state ‘offline’ with input ‘connect’
to state ‘offline’ which is obviously not part of the real automaton
in Figure 1a. This incorrect observation may have happened due to
any number of reasons: For example, the successful connection to
the server in between the two steps was not logged due to message
loss and as such made the trace non-deterministic.

At this point, regular SAT inference would report that the given
problem with traces _𝑇_ = { _𝑡_ 0 _,𝑡_ 1 _,𝑡_ 2 } is unsatisfiable as no deterministic automaton exists. It is true that no such automaton exists,
however, it would be more useful to receive the _best possible_ deterministic automaton using _as much of the traces as possible_ instead
of not getting any result at all.
Building the SAT problem again with two states and traces _𝑇_ =
{ _𝑡_ 0 _,𝑡_ 1 _,𝑡_ 2 } analogous to before and solving it with PMSAT gives us
the following solution:
_𝜆_ ( _𝑠_ 0 _,_ offline)∧ _𝛿_ ( _𝑠_ 0 _,_ connect _,𝑠_ 1 )∧ _𝛿_ ( _𝑠_ 0 _,_ disconnect _,𝑠_ 0 )∧ _𝜆_ ( _𝑠_ 1 _,_ online)
∧ _𝛿_ ( _𝑠_ 1 _,_ connect _,𝑠_ 1 )∧ _𝛿_ ( _𝑠_ 1 _,_ disconnect _,𝑠_ 0 )∧ _𝜔_ ( _𝑡_ 0 _,_ 0 _,𝑠_ 0 )∧ _𝜔_ ( _𝑡_ 0 _,_ 1 _,𝑠_ 0 )∧
_𝜔_ ( _𝑡_ 0 _,_ 2 _,𝑠_ 1 ) ∧ _𝜔_ ( _𝑡_ 1 _,_ 0 _,𝑠_ 0 ) ∧ _𝜔_ ( _𝑡_ 1 _,_ 1 _,𝑠_ 1 ) ∧ _𝜔_ ( _𝑡_ 1 _,_ 2 _,𝑠_ 1 ) ∧ _𝜔_ ( _𝑡_ 1 _,_ 3 _,𝑠_ 0 ) ∧
_𝜔_ ( _𝑡_ 2 _,_ 0 _,𝑠_ 0 ) ∧ _𝜔_ ( _𝑡_ 2 _,_ 1 _,𝑠_ 0 ) ∧ _𝜔_ ( _𝑡_ 2 _,_ 2 _,𝑠_ 0 ) ∧ G( _𝑡_ 2 _,_ 2).
As can be seen from the solution, the second step in the trace _𝑡_ 2
was determined to be a glitch, for which no transition exists in the
inferred automaton. Visualising this solution results in Figure 1a
if only the _𝛿_ variables are taken into account. We call transitions
defined by the _𝛿_ variables assigned true by a solver _dominant_ transitions. An automaton using only dominant transitions is called
_dominant automaton_ moving forward.
We may also visualise the glitch G( _𝑡_ 2 _,_ 2 ) by adding the transition
_𝛿_ _𝑔_ ( _𝑠_ 0 _,_ connect _,𝑠_ 0 ), as seen in Figure 1b, by taking _𝑖_ 2 of trace _𝑡_ 2 and
adding it between the states of steps _𝜔_ ( _𝑡_ 2 _,_ 1 _,𝑠_ 0 ) and _𝜔_ ( _𝑡_ 2 _,_ 2 _,𝑠_ 0 ) . We



will denote transitions traversed in the trace but marked as a glitch
with _𝛿_ _𝑔_ and call them _glitched transitions_, which are drawn in red.
At this point the glitch in the trace and the automata in Figures 1a
and 1b may be examined to determine the validity of the result or to
evaluate the steps marked as glitches in the trace. In this example,
the glitch stems from the incompatibility between traces _𝑡_ 0 and _𝑡_ 2,
which cannot be resolved by adding more states to the inferred
automaton, i.e., non-determinism instead of overgeneralisation. As
we will show in the next section, some types of glitches may and
should be resolved by inferring automata with more states.
In this section, we answered RQ 1, showing that it is possible to
mine models from noisy data using the PMSAT encoding described
above and demonstrating its use on an example.


**4** **PRACTICAL CONSIDERATIONS**


The procedure above can be used to mine models from traces that
include non-deterministic behaviour or noise given the number of
states _𝑛_ the inferred automaton should have. However, in practice
the real number of states of the underlying system is not known
in advance and therefore cannot be used as a parameter in the
learning procedure. In this section we provide some guidelines on
how to determine _𝑛_ and on how to choose an automaton out of a

range of automata with different _𝑛_ that should be "as deterministic
as possible", having few glitches and yet generalising the behaviour
recorded in the traces as well as possible. We also provide general
remarks about using the PMSAT inference procedure in practice
and present an example on how to apply the guidelines.


**4.1** **Considerations for Choosing** _𝑛_


First, it is important to note that the smallest possible automaton
that can be inferred from a trace has exactly _𝑛_ = | _𝑂_ | states. Assuming that _𝑂_ is calculated from the outputs observed in the traces,
such that _𝑂_ = [�] _𝑡_ ∈ _𝑇_ [{] _[𝑜]_ _𝑘_ [|] _[𝑘]_ [∈[] [0] _[,]_ [ |] _[𝑡]_ [|)}] [, and due to the fact that every]
state assigned to a step in the trace must have the corresponding
output (Equation 4), then any call to the solver with _𝑛_ _<_ | _𝑂_ | will be
unsatisfiable. Additionally, defining _𝐼_ or _𝑂_ to be different from the
inputs and outputs observed in the trace respectively is bound to
provide unsatisfiable or at least unhelpful results, as the trace then
cannot be correctly represented.
Conversely, the solver will always produce a valid result for
any _𝑛_ ≥| _𝑂_ | . Usually, the solver will use new states to encode
glitches into dominant transitions and thereby decrease the number of glitches in the solution, which is of course the objective
of the PMSAT algorithm. Alternatively, as there is no notion of
reachability in our SAT encoding, new states may always be added
by connecting the transitions of a new state to any other state in
the automaton, thus creating an _unreachable_ state, which is demonstrated in the example in Section 4.2. Therefore, inferred automata
with increasing number of states _𝑛_ will always have the same or
decreasing number of glitches.
To better analyse and compare the automata with different _𝑛_
we can use the solutions of the solver to build a _stochastic_ Moore

machine that not only includes glitches but also shows the _frequen-_
_cies_ of transitions, i.e., how often each transition was taken in the
traces. This can be done by replaying the trace using the _𝜔_ of the
solution variables and counting the number of times a transition


It’s Not a Feature, It’s a Bug ICSE ’24, April 14–20, 2024, Lisbon, Portugal



was taken. Figures 2a, 2b and 2c show such stochastic Moore machines all learned from the same trace but with different _𝑛_, where
dominant transitions are black, glitched transitions are red and the
frequencies of both are written in parentheses.
Ideally, we would get a **small** automaton, that has **few glitches**
with **low transition frequencies** and for which dominant transitions have **high frequencies** . Small automata are preferable because they generalise better than larger ones. The larger the automaton the more observed behaviour will be encoded into states

up to and including outliers, special cases or noise, which is often
unwanted. Additionally, observing certain interactions more often
in the traces gives us more confidence that said transition is real
behaviour of the system and not noise. Thus, it is preferable for
dominant transitions to have high frequencies. In contrast, if a transition that was marked as a glitch has a high frequency then this
would imply said transition should be encoded into the automaton
as a dominant transition.

The following guidelines (GL) inform about the best possible
choice of _𝑛_ :


GL 1: Choose _𝑛_ = | _𝑂_ | to infer the smallest possible automaton.
GL 2: If the solution has too many glitches, increment _𝑛_ .
GL 3: If the resulting automaton has frequently used glitches, increment _𝑛_ (we have generalised too much).
GL 4: If the resulting automaton has too many low frequency dominant transitions, decrement _𝑛_ (we have encoded outliers
into the automaton that are likely to be glitches).


It is recommended to evaluate the _change_ in glitches and frequencies instead of absolute numbers as, depending on the data,
some automata might already have very high or low frequencies.
For example, if the traces are not representative or complete, then
even the smallest automaton might not be input-complete already
and, as such, generally have lower dominant frequencies.
Just minimising the number of glitches, even if an automaton
with zero glitches can be found, is often not recommended because
such an automaton is often simply a tree of all given traces. This
is especially true if an automaton should be inferred from only a
single trace, in which case there does always exists an automaton
with zero glitches in the form of a line. There exists a certain balance
between _generalising_ behaviour and _precisely_ representing the given
data that must be determined for each set of traces and each use

case. This "best" result depends on the acceptable percentage of
glitches in the traces and the desired frequencies. For example,
if the desired result should be input-complete then all dominant
transitions should have a frequency of at least one.
As already stated the inferred automata might include states that
are not reachable via dominant transitions. If the number of such

dominant reachable states _𝑛_ _𝑟𝑒𝑎𝑐ℎ_ _< 𝑛_ then this means that only
glitches lead to the unreachable states. Most of the time the resulting
automaton is not the best one, as the number of glitches is only
artificially lowered without improving the dominant automaton.
However, it is possible that some outputs are only observed once or
very rarely, in which case the transitions into the states with these
outputs could correctly be marked as glitches.
Lastly, automata with different _𝑛_ may be checked for _bisimilarity_ .
We use the standard definition of bisimilarity [ 13 ], namely that two
automata are bisimilar if both simulate each other. We only compare



**(c) Inferred stochastic Moore machine with** _𝑛_ = 5 **states of ping-pong server**
**with** 4 **glitches**


**Figure 2: Stochastic Moore machines of ping-pong server.**


dominant automata for bisimilarity. In case two automata with
different _𝑛_ are bisimilar, the smaller automaton may be preferable.


**4.2** **Inferring Examples with Different** _𝑛_


A simple example ping-pong server serves as a demonstration of the
use of the guidelines and transition frequencies above. Figures 2a, 2b
and 2c are the automata inferred from a set of traces using an _𝑛_ of
three, four and five states, respectively. We chose to visualise the
results as stochastic Moore machines in which the glitches are red
and the frequencies are written in parentheses after the input of
each transition. The sum of all steps over the set of traces used to





ping (65)

















**(a) Inferred stochastic Moore machine with** _𝑛_ = 3 **states of ping-pong server**
**with** 31 **glitches**





























**(b) Inferred stochastic Moore machine with** _𝑛_ = 4 **states of ping-pong server**
**with** 5 **glitches**



connect (182)




















ICSE ’24, April 14–20, 2024, Lisbon, Portugal Felix Wallner, Bernhard K. Aichernig, and Christian Burghard



**Table 2: Statistics of inferring ping-pong server with differ-**
**ent** _𝑛_ **as parameter, with** _𝑛_ _𝑟𝑒𝑎𝑐ℎ_ **dominant reachable states,**
**number of glitches and different statistics of frequencies (fr.)**
**for glitched** _𝛿_ _𝑔_ **and dominant** _𝛿_ **transitions.**

|𝑛|𝑛𝑟𝑒𝑎𝑐ℎ|# Glitches|Mean 𝛿𝑔fr.|Max 𝛿𝑔fr.|Min 𝛿fr.|
|---|---|---|---|---|---|
|3|3|31|7.75|26|65|
|4|4|5|1.25|2|26|
|5|4|4|1.33|2|1|
|6|4|4|1|1|0|
|7|4|4|1|1|0|



infer these examples was 619. Thus, the sum of all frequencies is
also 619 in each automaton. Five of these steps were faults, which
is a little less than 1% of the total amount of steps.
Using the guidelines above, we first infer the smallest possible
automaton with _𝑛_ = | _𝑂_ | = 3 in Figure 2a (GL 1). The solution
for _𝑛_ = 3 has 31 glitches, which is equivalent to the sum of the
frequencies on all glitched (red) transitions in the automaton, about
5% of all steps in our set of traces. 5% is already a high amount of
glitches, which means we would tend towards increasing _𝑛_ (GL 2),
although it could be acceptable depending on the quality of the data
and the specific use case. Additionally, the glitched ‘ping’ transition
from ‘ack’ to ‘off’ has a very high frequency, which also prompts
us to increase _𝑛_ (GL 3).
Taking a look at Figure 2b we can see that this is a much better automaton in accordance with our guidelines: The number of
glitches fell drastically from 31 down to five, approximately 1% of
_𝑡_ _𝑠𝑡𝑒𝑝𝑠_, and there are no longer any glitches with high frequencies,
the highest being two in comparison to 26 before. Additionally, all
the dominant transitions still have high frequencies meaning no
outliers were encoded into states. This could be a good candidate
for a final result.
Finally, we check the next automaton in Figure 2c with _𝑛_ = 5
states. Here the solver was able to reduce the number of glitches
down to four. However, there are multiple indicators that this is not
a good result: Firstly, the number of states actually reachable via
dominant transitions _𝑛_ _𝑟𝑒𝑎𝑐ℎ_ is only four instead of five. One ‘ack’
state can only be reached via the glitched ‘connect’ transition. This
is a trick the solver uses quite frequently to reduce the number of
glitches only if no other more meaningful improvement is possible.
The ‘connect’ transition from the unreachable state to the other

‘ack’ state is now dominant and, as such, does not count towards
the number of glitches anymore. Secondly, the two new dominant
transitions only have a frequency of one, which implies that outliers or special cases were encoded into states (GL 4). Lastly, the
dominant automata with _𝑛_ = 4 and _𝑛_ = 5 are bisimilar and as such

are not distinguishable by inputs and outputs.
Taking a look at Table 2 to verify our analysis from above we
can see the drastic changes in the number of glitches as well as in
mean and maximum frequencies of _𝛿_ _𝑔_ between _𝑛_ = 3 and _𝑛_ = 4.
Conversely, only a single glitch is removed between _𝑛_ = 4 and _𝑛_ = 5
while we suddenly have dominant transitions with a frequency
of only one, which is the encoding of the glitch into a dominant

transition.



Therefore, choosing between these automata, we would choose
Figure 2b with _𝑛_ = 4 states. In this case, this would have been correct
as the dominant automaton of this figure was the ground truth from
which we generated a set of traces and randomly discarded inputoutput pairs to simulate faults in the data.
One last important point is that the dominant automata for _𝑛_ = 4,
_𝑛_ = 5, _𝑛_ = 6 and _𝑛_ = 7 are all _bisimilar_ and, as such, cannot be
distinguished by observations alone. All four automata have only
four reachable states. In a sense, the only valid choices are between
the _𝑛_ = 3 and _𝑛_ = 4 automata as the others are bisimilar to _𝑛_ = 4.

That does of course not mean that all automata with _𝑛_ _>_ 7 will

be bisimilar to _𝑛_ = 4 or one of them could not be a better solution,
however, in this case closer analysis of the remaining four glitches
would show that they are real non-determinism that cannot be
resolved with the addition of more states.

In this section, we answered RQ 2, outlining the practical considerations that should be taken into account when applying PMSAT
and demonstrating the use of the guidelines on an example.


**5** **IMPLEMENTATION AND EVALUATION**


In this section, we present an implementation of the PMSAT inference algorithm defined in Section 3 and evaluate its performance in
terms of its ability to infer the correct model from faulty data and
its computation speed based on the number of states, length of the
trace, number of faults and types of faults. We also compare PMSAT
to the IO ALERGIA [ 30 ] algorithm as a baseline. Additionally, we
present three use cases to evaluate the algorithm in practice using
the considerations outlined in Section 4.
The evaluation is based on our implementation in Python [ 53 ] [1],
which uses **AALpy** [ 38 ], an automata learning library used for the
handling, visualisation and generation of Moore machines and its
implementations of L [∗] [ 2 ] and random walks for the generation
of our test traces, as well as **PySAT** [ 20 ], a Python interface for a
variety of SAT solvers as well as different PMSAT implementations.


**5.1** **PMSAT Inference Performance**


_5.1.1_ _Benchmarking Setup._ To test the performance and accuracy
of the PMSAT inference algorithm presented in Section 3, we used
the following setup: First, we generated ten random Moore machines with | _𝐼_ | = 3 from a given number of states _𝑛_ and output
alphabet size | _𝑂_ | . Next, we generated traces representative of each
Moore machine by running the L [∗] algorithm [ 2 ] and recording the
observed inputs and outputs. Finally, we discarded a certain percentage of steps, i.e., input-output pairs, randomly from the traces to
introduce non-determinism and simulate message loss or a similar
type of fault. We varied the size of the output alphabet | _𝑂_ | ∈[ 2 _,_ 9 ],
the number of states _𝑛_ ∈[| _𝑂_ | _,_ 17 ] and the percentage of discarded
steps _𝑔_ ∈{ 0% _,_ 1% _,_ 2% _,_ 5% _,_ 10% } for a total of 500 combinations. For
these parameters and Moore machines the longest traces produced
had 2300 steps. The CNF formulas for these automata had between
450 and one million hard clauses, with a median of 105054, and
between 200 and 50000 variables, with a median of 8225.
We then attempted to infer an automaton from such mutated
traces, which we refer to as an _experiment_ . The experiments were
performed with the _correct number of states as its input_ and given a


1 [The algorithm is maintained at https://gitlab.com/felixwallner/pmsat-inference](https://gitlab.com/felixwallner/pmsat-inference)


It’s Not a Feature, It’s a Bug ICSE ’24, April 14–20, 2024, Lisbon, Portugal



**Table 3: Percentage of the 400 experiments per number of**
**states that ran into the one hour timeout.**

|𝑛|8|9|10|11|12|13|14|15|16|17|
|---|---|---|---|---|---|---|---|---|---|---|
|timeout %|0.6|0.3|0.5|1.5|3.5|5.8|10.3|17.5|27|33|



_one hour time limit_ each, running on an Ubuntu 22.02 system with an
AMD Ryzen 9 5950X CPU. We recorded solve time and correctness,
i.e., whether or not the correct automaton could be mined, along
with some other metrics. An experiment counts as correctly inferred
only if the resulting model is _bisimilar_ to the original and the result
could be calculated in the one hour time limit. The solve time for

the correct number of states is a significant metric insofar as the
inference algorithm can be run for any number of different _𝑛_ on the
same set of traces in parallel because all inferences are mutually
independent. Therefore, we only ran the algorithm for the correct
number of states to save time during testing.


_5.1.2_ _Partial Max-SAT Implementations._ There are a variety of
implementations of the Partial Max-SAT algorithm: Morgado et
al. [ 35 ] give an overview of different iterative and core-guided
algorithms.
First, we evaluated the performance of three different Partial
Max-SAT implementations in PySAT [ 20 ], namely the Linear SATUNSAT (LSU) [ 32, 35 ], Fu and Malik (FM) [ 14, 29 ] and relaxable
cardinality constraints (RC2) [ 21, 34, 36 ] algorithms. As RC2 performed best in this initial screening we chose it for the rest of our
benchmarks. RC2 is core-guided and has to perform number-ofglitches-many SAT calls until a satisfiable solution is found.
As a practical consideration we mention here LSU, which has the
advantage over RC2 that it can be interrupted and still result in a
satisfiable, if sub-optimal, solution. This could be useful if the solver
is given a time budget and a sub-optimal solution is acceptable.


_5.1.3_ _Evaluation._ Here we evaluate the following points:
**Correct Inference and Runtime.** We evaluate the percentage
of correctly inferred models and runtime of PMSAT in Figures 3a, 3b,
and 3c: The first two figures show the percentage of correct inferences depending on the output alphabet size and the number of
dropped steps, respectively, while the last figure shows the average
solve time for the latter. Timing out after one hour counts both
towards incorrect inferences as well as towards the mean runtime.

We show the percentage of timeouts separately in Table 3 as the
timely computation of our results is an important aspect of the
inference algorithm. No timeouts occurred for _𝑛_ ≤ 7.
In Figure 3a we can see that the larger the difference between | _𝑂_ |
and _𝑛_, the worse performance gets. This can in part be explained by
Equation 1 because all outputs can be paired with every state and
our optimisation in Equation 8 only fixes the first | _𝑂_ | state outputs.
The even larger influence on correct inferences and solve time is
the amount of faults in the traces, which can be seen in Figures 3b
and 3c. While not every step discarded from the trace will result in
a glitch, most of them do. They impact the runtime insofar as RC2
has to perform as many calls to the SAT solver as there are glitches
to find the maximum number of satisfiable soft clauses.
The number of states _𝑛_ with which to infer the automata also has

an impact on runtime. In Section 3.2, we showed that the number



of clauses grows quadratically with the number of states. Even
with glitch-free traces PMSAT started running into timeouts with
_𝑛_ ≥ 17, which can be seen in Figure 3b. This would of course mean
that traces with glitches, which would require more than a single
SAT call, would have taken even longer to calculate.
To summarise, the algorithm solves fastest and most reliably
with a low number of faults in the traces due to the multiple SAT
calls necessary for RC2 to find the best possible solution as well as
with a high number of different outputs and small _𝑛_ .
**Runtime wrt. Trace Steps.** The runtime with respect to the
length of the trace for 100 randomly generated automata with
_𝑛_ = 8 _,_ | _𝑂_ | ≤ 5 and 1% discarded trace steps is presented in Figure 3e.
Similarly to our other experiments, the representative traces were
first learned with L [∗], then 12 different experiments were performed
where the traces were extended by up to 5500 steps using random
walks for a total of 1200 experiments. The box plots in Figure 3e
show the solving time for these experiments, collecting traces into
buckets with 1000 steps each. Each box encompasses the first quartile ( _𝑄_ 1 ) to third quartile ( _𝑄_ 3 ) and the whiskers are plotted at 1 _._ 5
times the interquartile range ( _𝑄_ 3 − _𝑄_ 1 ) while the points are outliers.
As can be seen from the figure, for these parameters the solving
time was seconds for traces up to 3000 steps, minutes for up to 6000
steps and hours for larger traces. More than half of all traces longer
than 6000 steps timed out after one hour while not a single timeout
occurred for traces shorter than 1000 steps.
**Different Fault Types.** Our benchmarks focus on discarded
trace steps as fault type due to it translating to a very common
real world problem, namely message loss. This fault type fulfils
both requirements of the type of noise our algorithm can deal with:
_sparsity_ and _uniform distribution_ across the entire trace. We evaluated three additional fault types, which fulfil these requirements:
_duplicating_ random steps, i.e., input-output pairs, which models a
message being sent multiple times, _inserting_ random steps, which
could be due to interleaving messages between different actors,
and _swapping_ two neighbouring steps, which could appear due
to timing issues in the transmission, e.g., congestion. Correctness
(excluding timeouts) for all four fault types is similar. The major
difference between them is in how many glitches they produce
in the algorithm: A single discarded step induces at most one, an
inserted or duplicated step at most two, and two swapped steps at
most three glitches. This is because each transition to or from an
inserted or swapped step may be a separate glitch as our definition
of glitches is based on transitions, which explains the difference
in performance in Figure 3d. Therefore, while our algorithm can
deal with other fault types, the fault type can have an impact on
performance due to our algorithm’s glitch representation.
**Comparison to IO ALERGIA.** Finally, we compare our approach to the IO ALERGIA [ 30 ] algorithm as a baseline. It is implemented in AALpy [ 38 ] and was recently used [ 8, 37, 48 ]. The
reasons why we chose IO ALERGIA for our comparison were the
following:


(1) We wanted to compare to an algorithm that does not require
interaction with the system but is able to work with preexisting traces. This rules out active inference algorithms,
like [1], [18] and [43].


ICSE ’24, April 14–20, 2024, Lisbon, Portugal Felix Wallner, Bernhard K. Aichernig, and Christian Burghard



100%


80%


60%


40%


20%







60


50


40





100%


80%


60%


40%


20%



0%

|Col1|Col2|Col3|Col4|Col5|Col6|Col7|Col8|
|---|---|---|---|---|---|---|---|
|||||||||
|||||||||
||_𝑂_|<br>|_𝑂_|<br>|_𝑂_||≤2<br> ≤3<br> ≤4|||||||
||_𝑂_|<br>|_𝑂_|<br>|_𝑂_|≤5<br> ≤6<br> ≤7|||||||
||_𝑂_|<br>|_𝑂_||≤8<br> ≤9|||||||



2 4 6 8 10 12 14 16


number of states _𝑛_


**(a) Percentage of correctly inferred models based on**
_𝑛_ **and the output alphabet size, 50 experiments over**
**all different percentages of discarded trace steps.**



30


20


10


0

|di<br>di|scard<br>scard|ed 0%<br>ed 1%|Col4|Col5|Col6|Col7|
|---|---|---|---|---|---|---|
|di<br>di<br>|scard<br>scard<br>|ed 2%<br>ed 5%<br>|||||
|di|car|ed 10%|||||
||||||||
||||||||
||||||||
||||||||



2 4 6 8 10 12 14 16


number of states _𝑛_


**(c) Average solving time based on** _𝑛_ **and the percent-**
**age of discarded trace steps, 80 experiments over all**
**output alphabet sizes**


1


|Col1|Col2|Col3|Col4|Col5|Col6|Col7|Col8|
|---|---|---|---|---|---|---|---|
|||||||||
|||||||||
|d<br>d<br>d|iscard<br>iscard<br>iscard|ed 0%<br>ed 1%<br>d 2%||||||
|d<br>d|iscard<br>iscard|ed 5%<br>ed 10%||||||


|discard<br>duplica|te|Col3|Col4|Col5|Col6|Col7|
|---|---|---|---|---|---|---|
|insert<br>swap|||||||
||||||||
||||||||


|Col1|Col2|Col3|Col4|Col5|Col6|
|---|---|---|---|---|---|
|||||||
|PMSAT<br>_𝜖_= 10/|<br>_𝜖_= 10/|<br>_𝜖_= 0_._5|_𝑇_|<br>_𝑇_| DET|||||
|_𝜖_= 0_._5<br>_𝜖_= 0_._00|DET<br>5|||||
|_𝜖_= 0_._00|5 DET|||||



0

6 8 10 12 14 16


number of states _𝑛_


**(f) Average F** 1 **-score for** 10 **random automata per num-**
**ber of states with** | _𝑂_ | ≤ 5 **and** 1% **discarded trace steps**
**for PMSAT and IO ALERGIA with different** _𝜖_ **.**



60


50







40


30


20


10


0


6 8 10 12 14 16


number of states _𝑛_


**(d) Average solving time based on** _𝑛_ **and different**
**types of faults all with** 1% **of steps randomly affected,**
**for** 10 **random automata each.**



0%

2 4 6 8 10 12 14 16


number of states _𝑛_


**(b) Percentage of correctly inferred models based on**
_𝑛_ **and the percentage of discarded trace steps, 80 ex-**
**periments over all output alphabet sizes.**


60


50


40


30


20


10


0


0-1k 1k-2k 2k-3k 3k-4k 4k-5k 5k-6k 6k-7k


number of trace steps


**(e) Solving time based on number of trace steps for**
_𝑛_ = 8 _,_ | _𝑂_ | ≤ 5 **and** 1% **discarded steps for** 100 **random**
**automata, each trace extended with random walks.**



0 _._ 9


0 _._ 8


0 _._ 7


0 _._ 6


0 _._ 5


0 _._ 4


0 _._ 3


0 _._ 2


0 _._ 1



**Figure 3: Different benchmark results on randomly generated Moore machines**



(2) The algorithm should be able to work directly with noise
so that both algorithm could be compared using the same
noisy traces. This rules out algorithms that cannot cope with
non-deterministic data (traces), like [41] and [15].
(3) The algorithm should support input-output behaviour directly. Particularly, the resulting model should be a Moore
machine or at least a closely related formalism to enable a
sensible comparison. This rules out algorithms that produce
different model types like [49], [52], [31] and [12].


We are not aware of an algorithm that fulfils all of these points explicitly, however, a close enough match to Moore machines would
be Markov-decision processes, which are equivalent to our stochastic Moore machines. We chose IO ALERGIA because a mature

implementation was readily available at that time. We consider a
future comparison with MDP-BW [ 8 ] implemented in Jajapy [ 44 ].
Further discussion on different algorithms that were considered for
comparison can be found in the related work in Section 6.
Note that we can interpret our PMSAT-based approach as first
learning a stochastic Moore machine and then extracting a (deterministic) Moore machine by removing the transitions with the
lowest frequencies/probabilities if multiple transitions on the same
input from the same state exist. IO ALERGIA can also be adapted
to produce a (deterministic) Moore machine in this way. We call



the algorithms _stochastic_ and _deterministic_ to differentiate between
the produced model types. We evaluate different values for the
parameter _𝜖_, which configures the significance level of statistical
tests for difference of candidate states, where lower levels lead to
smaller automata. In Figure 3f we compare three automata, namely
the deterministic PMSAT, stochastic IO ALERGIA and deterministic IO ALERGIA with the deterministic ground truth automaton
via conformance testing: We first sample 10000 random traces via
random walks from both the ground truth and from the learned
automaton. Then we compute the fraction of samples that can be
produced by the other automaton respectively. These fractions are
the precision and recall for the learned automata w.r.t. the ground
truth. Finally, the harmonic mean between these two fractions is
called the F 1 -score [ 24 ]. This approach compares language similarity, with scores closer to one meaning the languages are more
similar, while also allowing the comparison between stochastic and
deterministic automata. As can be seen in Figure 3f, PMSAT performs vastly better in this respect than both regular IO ALERGIA
and its simple deterministic variant.
**Optimisation.** Without Equation 8 the total solve time for evaluating the entire benchmarking set takes about 753 hours instead
of 500 hours, about 50% longer, and on average about 182 seconds
longer per experiment with 250 additional timeouts.


It’s Not a Feature, It’s a Bug ICSE ’24, April 14–20, 2024, Lisbon, Portugal



**5.2** **Use Case Studies**


We present three different use cases, the first two of which are automotive measurement devices, which have a different fault model
in the form of time-triggered state changes, and a Bluetooth Low
Energy device, which experiences message loss.


_5.2.1_ _Automotive Measurement Devices._ A class of devices especially of interest are automotive measurement devices, which we
want to model. We present two different ones here for which we
both learned from _a single_ representative trace because resetting
either of them into their respective starting state would have taken
a relatively long time. Both devices are designed to run continuously. After inferring solutions for different _𝑛_ and choosing a result
we verified our choice with domain experts. All traces and results
can be found in full online [ 53 ]. The measurement devices have
internal state variables that can be queried to find out the current
internal state. However, some of the internal state labels appear
_multiple times_ for different states due to other unobservable variables. Otherwise, every state would have a unique output and the
devices would be trivial to model. During testing we polled the
internal state variable of the devices on average every 0 _._ 12 seconds


_Time-Triggered State Changes._ Both devices exhibit behaviours
that induce faults into the traces, which we call _time-triggered_ state
changes. These are state changes that are initiated by the device
without any external input and that are also not immediately obvious to an outside observer without additional state queries. For our
purposes, we can think of these state changes as being triggered
by a timer that starts running after a specific state is entered. This
may or may not be the actual underlying mechanism of such state
changes in practice. In both devices most states represent actions
that the device can do, such as measuring, which automatically
returns to the standby state once the action is completed. Usually,
we will quickly explore a state and leave it via a transition, but if
the device stays in a time-triggered state for too long or the timer is
very short, then it may _appear_ that the last input we used lead to a
different state when in reality the device performed a time-triggered
transition in-between external inputs. In order to better represent
this behaviour we added an additional input, namely ‘WAIT’, which
would wait until a time-triggered state change occurred or for a
maximum of 5 minutes if no such state change is observed. Nevertheless input race conditions were still possible and resulted in the
glitches we observed in our traces.


_Advanced Particle Counter._ The _AVL Advanced Particle Counter_

(APC) is a device to measure the number of solid particles in a stream
of exhaust gas through laser scattering on individual particles [ 6 ].
The model of the APC was inferred from a single trace with 385
steps, | _𝐼_ | = 5 and | _𝑂_ | = 7 for which the results are shown in Table 4.
Each of these PMSAT solves took less than a second individually.
We can see that until _𝑛_ = 9 the number of glitches falls considerably for such a short trace. Then _𝑛_ = 10 does not remove any
glitches and as such is not of interest, while _𝑛_ = 11 does remove
a glitch again. The automata with _𝑛_ = 12 and _𝑛_ = 13 both have
a large number of transitions only taken once, which might be
special cases encoded into the automaton, and have a number of
non-input-complete states. Choosing between _𝑛_ = 9 and _𝑛_ = 11 is



**Table 4: Statistics of inferring the APC with different** _𝑛_ **as**
**parameter, with** _𝑛_ _𝑟𝑒𝑎𝑐ℎ_ **dominant reachable states, number**
**of glitches and different statistics of frequencies (fr.) for**
**glitched** _𝛿_ _𝑔_ **and dominant** _𝛿_ **transitions.**

|𝑛|𝑛𝑟𝑒𝑎𝑐ℎ|# Glitches|Mean 𝛿𝑔fr.|Max 𝛿𝑔fr.|Min 𝛿fr.|
|---|---|---|---|---|---|
|7|7|12|3|6|4|
|8|8|6|2|4|4|
|9|9|2|1|1|1|
|10|10|2|1|1|0|
|11|11|1|1|1|0|
|12|12|1|1|1|0|
|13|13|0|0|0|0|



**Table 5: Statistics of inferring the Smoke Meter with different n as parameter, with n_reach dominant reachable states, number of glitches and different statistics of frequencies (fr.) for glitched δ_g and dominant δ transitions.**

|  n | n_reach | # Glitches | Mean δ_g fr. | Max δ_g fr. | Min δ fr. |
| -: | ------: | ---------: | -----------: | ----------: | --------: |
|  9 |       ? |         ?? |         ??.? |          ?? |         ? |
| 10 |       ? |         ?? |         ??.? |          ?? |         ? |
| 11 |      ?? |          ? |            ? |           ? |         ? |
| 13 |      ?? |          ? |            ? |           ? |         ? |
| 14 |      ?? |          ? |            ? |           ? |         ? |



more tricky. We decided on _𝑛_ = 9 due to its more general behaviour
and it being input-complete, which turned out to be correct.


_Smoke Meter._ The _AVL Smoke Meter_ is an automotive measure
ment device to measure the amount of smoke in a stream of ex
haust gas through the optical blackening of a filter paper [ 7 ]. Table 5
shows the learning process of the Smoke Meter using the guidelines
described in Section 4 from a single trace with 789 steps, | _𝐼_ | = 6
and | _𝑂_ | = 9. Individually, PMSAT runs took less than a second.
Interestingly, the automata with _𝑛_ = 9 and _𝑛_ = 10 only had
eight reachable states and were bisimilar to each other. Because
we wanted to have all model outputs reachable, these two models
would not be the final results. With _𝑛_ = 11 the glitches were reduces
drastically, which also turned out to be the correctly inferred model.


_5.2.2_ _Bluetooth Low Energy._ One of the fault types we are especially interested in is message loss. In the case study on learning Bluetooth Low Energy (BLE) devices by Pferscher and Aichernig [ 43 ], they present an active learning approach for multiple
BLE devices that regularly deals with message loss. From their case
study, we selected the _Nordic nRF52832 RF System on a Chip_ [ 40 ] for
our own use case for two reasons: Firstly, it has a relatively small
state space and secondly it took the longest to learn for the evaluated BLE devices with smaller state spaces. The correctly learned
automaton and the software to interact with the BLE devices is

available in the repository [ 42 ] connected with their case study.
From this nRF52832 automaton, we dropped a single input due to
the device having 27 (Moore) states originally in order to make it


ICSE ’24, April 14–20, 2024, Lisbon, Portugal Felix Wallner, Bernhard K. Aichernig, and Christian Burghard



**Table 6: Statistics of inferring the nRF52832 BLE chip with dif-**
**ferent** _𝑛_ **as parameter, with** _𝑛_ _𝑟𝑒𝑎𝑐ℎ_ **dominant reachable states,**
**number of glitches and different statistics of frequencies (fr.)**
**for glitched** _𝛿_ _𝑔_ **and dominant** _𝛿_ **transitions.**

|𝑛|𝑛𝑟𝑒𝑎𝑐ℎ|# Glitches|Mean 𝛿𝑔fr.|Max 𝛿𝑔fr.|Min 𝛿fr.|
|---|---|---|---|---|---|
|9|9|106|8.83|16|7|
|10|10|40|5.71|10|7|
|11|11|33|4.71|10|2|
|12|12|25|3.13|11|3|
|13|13|14|2|8|2|
|14|14|2|1|1|2|
|15|14|1|1|1|0|
|16|15|1|1|1|0|



better comparable to the sizes of the other use case studies. We
discuss the algorithm’s performance for larger state spaces above.
We then used the W-method by Chow [ 11 ] and Vasilevskii [ 50 ]
to generate a set of 224 representative input sequences, which we
extended to length ten each with random inputs. We then _replayed_
these input sequences on the real nRF52832 BLE device, which led
to packet loss in the thus generated traces with a total of 2240 steps.
It took about three hours to replay all 224 traces on the device.
Finally, we inferred automata from these generated device traces,
for which the results can be found in Table 6, with | _𝐼_ | = 8 and
| _𝑂_ | = 9. Each of these PMSAT runs took less than ten seconds
individually. As can be seen up to and including _𝑛_ = 13, there is a
high frequency of glitches, which are encoded into the automaton
with _𝑛_ = 14 states. The automaton with _𝑛_ = 15 is bisimilar to the

previous one and all automata with _𝑛_ _>_ 15 include at least one
state that is not reachable via dominant transitions, as shown in
the example in the previous section in Figure 2c. The automaton
with _𝑛_ = 14 was correctly inferred.
In this section, we answered RQ 3, showing the performance
of our approach in regards to different criteria on benchmarks in
Section 5.1.3 and on three use case studies.


**6** **RELATED WORK**


Inferring a minimal automaton with a given number of states and
consistent with a set of traces was shown to be NP-hard by Gold [ 16 ].
Nevertheless, there exists a variety of inference approaches for different types of automata using, among others, CSP, SAT and SMT
solving: The problem was originally stated by Biermann and Feldman [ 9 ] as a CSP problem, which was later formulated as a SAT
problem by Grinchtein et al. [ 17 ]. Their approach was improved by
Heule and Verwer [ 19 ] by combining exact SAT solving with greedy
state-merging and heuristics for model inference. Avellaneda and
Petrenko [ 5 ] present an incremental approach especially for inferring automata from long traces. Neider [ 39 ] proposes a technique
to infer deterministic finite automata (DFAs) with a fixed number of
states. Smetsers et al. [ 46 ] infer DFAs, Mealy machines, and register
automata from observed behaviour using SMT solving. Tappler et
al. [47] uses SMT solving to learn timed automata.
Some inference algorithms do not rely on SAT or SMT solvers,
such as RPNI [ 41 ], which uses state merging to build a deterministic
automaton from a set of traces. Giantamidis et al. [ 15 ] formalise the



problem of learning Moore machines from traces. The hW-inference
algorithm [ 18 ] can infer a model from a single trace instead of requiring many samples. Luo et al. [ 28 ] present a distributed scalable
algorithm, while Busani and Maoz [ 10 ] present an approach that
allows for the sampling of traces with statistical guarantees for
better scalability.
All of these approaches assume that the data accurately represents the underlying FSM and does not contain non-deterministic
faults. There is a variety of inference methods for practical settings
that deal with non-deterministic behaviour:

One approach is to use _active_ inference where the system under learning can be actively queried to refine the inferred model.
This has the advantage of allowing multiple executions of the same
queries if inconsistencies are detected, but it requires the system to
be available, which is often not the case if data is taken from logs or
records. One such approach by Aichernig et al. [ 1 ] masks detected
non-determinism with sink states, which then allows them to use
a regular deterministic learning algorithm, such as L [∗] [ 2 ], to infer
the model. Another approach by Pferscher and Aichernig [ 43 ] uses
L [∗] to learn BLE devices. They experience message losses, connection errors and message delays, which they deal with by repeating
queries multiple times and discarding outlier traces.
An alternative approach is to model the underlying system differently to include this non-determinism. The downside of such
an approach is that the noise appears in the structure of the FSMs,
which is often not desirable, especially if the underlying system is
known to be deterministic. IO ALERGIA [ 30 ] uses state merging to
build stochastic finite automata from a set of traces. This allows it to
learn even if the traces are non-deterministic, however, the resulting automaton includes the non-deterministic behaviours. Bacci et
al. [ 8 ] improve on the model quality by obtaining a baseline model
of a Markov-decision process (e.g. from IO ALERGIA) and iteratively updating its transition probabilities. Emam and Miller [ 12 ]
infer extended probabilistic FSMs. Vazquez de Parga et al. [ 51 ]
present a family of inference algorithms for non-deterministic finite automata (NFAs), while Lardeux and Monfroy [ 26 ] formulate
the problem of learning an NFA of a certain size from data as a
SAT problem. While these methods can deal with the noise in our
data, they encode it directly into the inferred automaton and may
require postprocessing to remove it.
Some inference methods for deterministic models take noise

directly into account: Angluin and Laird [ 3 ] researched random
noise and how to compensate for it, Kearns [ 22 ] dealt with noise
in probabilistic learning, while Khmelnitsky et al. [ 23 ] researched
robustness of L [∗] with regards to learning DFAs from data with
random and structured noise. Sebban and Janodet [ 45 ] extended
the RPNI algorithm [ 41 ] by relaxing the state merging rules, to infer
DFAs from noisy data. Lucas and Reynolds [ 27 ] use an evolutionary
method for learning DFAs from noisy and noiseless data. Ulyantsev
et al. [ 49 ] mine DFAs from both noisy and noiseless data. They
use regular SAT solving and a different fault model that requires a
number of additional clauses not found in our own algorithm while
we leverage PMSAT to formulate the problem concisely. They define
an upper bound on the number of glitches, among other parameters,
and iteratively perform calls to the SAT solver to determine the
number of states of the automaton.


It’s Not a Feature, It’s a Bug ICSE ’24, April 14–20, 2024, Lisbon, Portugal



The MINT framework [ 52 ] and GK-tail+ [ 31 ] are able to mine
models from the richer class of deterministic extended FSMs from

traces consisting of events parametrized by data. MINT learns
guards in terms of parameters as part of the state machine by using
state merging. Furthermore, it infers data classifiers that are used
to resolve non-determinism during inference, which may address
inflexibilities such as noise or spurious events. GK-tail+ infers constraints on a per-transition basis. However, both methods do not
distinguish between input and output symbols like they are used
in Moore machines.

In conclusion, there exists a variety of model mining algorithms,
however, most differ in one of the following aspects: (1) Some cannot
handle noise and need pre-processing, which may require domain
knowledge. (2) Others learn non-deterministically or stochastically
and encode the noise directly into the model, which we seek to avoid.
(3) Some are able to deal with noise but require active interaction
with the system instead of learning from traces. (4) Finally, some
mine different types of models instead of Moore machines. Thus
our approach combines a set of specific capabilities in a novel way.
To the best of our knowledge the method presented in this paper
is the first using PMSAT for model inference from noisy data.


**7** **THREATS TO VALIDITY AND LIMITATIONS**


We identified the following threats to the validity of our work:
**Encoding of Glitches.** Our PMSAT encoding assumes glitches
to be transitions that are not present in the underlying automatons
_𝛿_ M . While we cannot guarantee that this encoding will suffice to
model all types of real-world glitches, it did work very well for the
different fault types encountered in our benchmarks and use cases.
**Systematic Faults.** Our algorithm targets sporadic, i.e., transient, and randomly distributed noise. This noise should not be included in the model due to it not being part of the system behaviour.
Contrary, systematic faults, i.e., non-trivial system behaviour such
as exceptions among others, will be modelled if it appears often
enough in the data. This is not only expected but also wished for
as model mining is often used to discover unexpected systematic
faults or insecure system behaviour. The inclusion of such systematic faults in the model is common to all model mining algorithms.
In the use case studies about the measurement devices, the underlying faults of the devices were systematic, i.e., the time-triggered
state changes, which happen only in certain states, however, due
to the abstraction of time the effects appear random (enough) in
the data for our algorithm to learn the correct models.
**Biased Benchmarks.** A possible threat to validity is that our
algorithm works only on selected systems or that our evaluation
was biased. To mitigate this bias we exclusively used randomly
generated automata in our benchmarks. Additionally, we provided
three practical use case studies from two very different domains:
communication protocols with BLE, and measurement devices with
the APC and Smoke Meter devices.

**Scalability.** The primary limitation of the algorithm is scalability,
due to the NP-hard nature of (partial) Max-SAT [ 25 ]. While the
algorithm might not be able to solve problems with hundreds of
states or millions of trace steps in reasonable time, we demonstrated
its capabilities for small to moderately large automata/traces (up to
17 states or 6000 trace steps), which are sufficient to learn industrial



real-world use cases like measurement devices or communication

protocols.


**8** **CONCLUSION**


We presented a novel approach based on Partial Max-SAT to infer
deterministic Moore machines from noisy data with a certain number of states. The approach is able to work with a single execution
trace or with a set of traces and will find a deterministic model
consistent with as many observations as possible. We further presented practical considerations regarding the best choice of the size
of the automaton and evaluated our method’s performance on a set
of randomly generated Moore machines with different parameters.
The preliminary experimental results show that the approach can
process traces up to 17 states or up to 6000 steps within few minutes. However, half of all our experiments with 17 states or longer
than 6000 traces timed out after one hour. Finally, we showed that
the method can deal with different fault types in data by means of
three use cases: Two industrial measurement devices, each inferred
from a single execution trace that experienced time-triggered state
changes, and one BLE device that experienced message loss. The
method is expected to be used for software and firmware regression
testing and serves as a basis for device simulation for digital twins.
Our future work may include direct comparison between this
approach and other state-of-the-art methods like the MDP-BW
algorithm [ 8, 44 ], as well as more extensive performance evaluation
against established benchmark automata.


**ACKNOWLEDGMENTS**


This work was a collaboration between AVL List GmbH and Graz

University of Technology in the LearnTwins project funded by the
Austrian Research Promotion Agency (FFG) under grant 880852.
We would like to thank Andrea Pferscher for providing the data for
the BLE use case and Benjamin von Berg for the fruitful discussions.
We also would like to thank the anonymous reviewers for their
valuable feedback and insightful comments.


**REFERENCES**


[1] Bernhard K. Aichernig, Christian Burghard, and Robert Korosec. 2019. LearningBased Testing of an Industrial Measurement Device. In _NASA Formal Methods_

_- 11th International Symposium, NFM 2019, Houston, TX, USA, May 7-9, 2019,_
_Proceedings (Lecture Notes in Computer Science, Vol. 11460)_, Julia M. Badger and
[Kristin Yvonne Rozier (Eds.). Springer, 1–18. https://doi.org/10.1007/978-3-030-](https://doi.org/10.1007/978-3-030-20652-9_1)
[20652-9_1](https://doi.org/10.1007/978-3-030-20652-9_1)

[2] Dana Angluin. 1987. Learning Regular Sets from Queries and Counterexamples.
_Information and Computation_ [75, 2 (1987), 87–106. https://doi.org/10.1016/0890-](https://doi.org/10.1016/0890-5401(87)90052-6)
[5401(87)90052-6](https://doi.org/10.1016/0890-5401(87)90052-6)

[3] Dana Angluin and Philip D. Laird. 1987. Learning From Noisy Examples. _Mach._
_Learn._ [2, 4 (1987), 343–370. https://doi.org/10.1007/BF00116829](https://doi.org/10.1007/BF00116829)

[4] Josep Argelich and Felip Manyà. 2007. Partial Max-SAT Solvers with Clause
Learning. In _Theory and Applications of Satisfiability Testing - SAT 2007, 10th_
_International Conference, Lisbon, Portugal, May 28-31, 2007, Proceedings (Lecture_
_Notes in Computer Science, Vol. 4501)_, João Marques-Silva and Karem A. Sakallah
[(Eds.). Springer, 28–40. https://doi.org/10.1007/978-3-540-72788-0_7](https://doi.org/10.1007/978-3-540-72788-0_7)

[5] Florent Avellaneda and Alexandre Petrenko. 2018. FSM Inference from Long
Traces. In _Formal Methods - 22nd International Symposium, FM 2018, Held as Part of_
_the Federated Logic Conference, FloC 2018, Oxford, UK, July 15-17, 2018, Proceedings_
_(Lecture Notes in Computer Science, Vol. 10951)_, Klaus Havelund, Jan Peleska, Bill
[Roscoe, and Erik P. de Vink (Eds.). Springer, 93–109. https://doi.org/10.1007/978-](https://doi.org/10.1007/978-3-319-95582-7_6)
[3-319-95582-7_6](https://doi.org/10.1007/978-3-319-95582-7_6)

[6] AVL List GmbH. Nov. 2019. _AVL 489 Particle Counter - product guide_ .

[7] AVL List GmbH. Sep. 2013. _AVL 415SE Smoke Meter - product guide_ .

[8] Giovanni Bacci, Anna Ingólfsdóttir, Kim G. Larsen, and Raphaël Reynouard. 2021.
Active Learning of Markov Decision Processes using Baum-Welch algorithm. In


ICSE ’24, April 14–20, 2024, Lisbon, Portugal Felix Wallner, Bernhard K. Aichernig, and Christian Burghard



_20th IEEE International Conference on Machine Learning and Applications, ICMLA_
_2021, Pasadena, CA, USA, December 13-16, 2021_, M. Arif Wani, Ishwar K. Sethi,
Weisong Shi, Guangzhi Qu, Daniela Stan Raicu, and Ruoming Jin (Eds.). IEEE,
[1203–1208. https://doi.org/10.1109/ICMLA52953.2021.00195](https://doi.org/10.1109/ICMLA52953.2021.00195)

[9] Alan W. Biermann and Jerome A. Feldman. 1972. On the Synthesis of Finite-State
Machines from Samples of Their Behavior. _IEEE Trans. Computers_ 21, 6 (1972),
[592–597. https://doi.org/10.1109/TC.1972.5009015](https://doi.org/10.1109/TC.1972.5009015)

[10] Nimrod Busany, Shahar Maoz, and Yehonatan Yulazari. 2019. Size and Accuracy
in Model Inference. In _34th IEEE/ACM International Conference on Automated_
_Software Engineering, ASE 2019, San Diego, CA, USA, November 11-15, 2019_ . IEEE,
[887–898. https://doi.org/10.1109/ASE.2019.00087](https://doi.org/10.1109/ASE.2019.00087)

[11] Tsun S. Chow. 1978. Testing Software Design Modeled by Finite-State Machines.
_IEEE Transactions on Software Engineering_ [4, 3 (1978), 178–187. https://doi.org/](https://doi.org/10.1109/TSE.1978.231496)
[10.1109/TSE.1978.231496](https://doi.org/10.1109/TSE.1978.231496)

[12] Seyedeh Sepideh Emam and James Miller. 2018. Inferring Extended Probabilistic
Finite-State Automaton Models from Software Executions. _ACM Trans. Softw._
_Eng. Methodol._ [27, 1 (2018), 4:1–4:39. https://doi.org/10.1145/3196883](https://doi.org/10.1145/3196883)

[13] Jean-Claude Fernandez and Laurent Mounier. 1991. "On the Fly" Verification
of Behavioural Equivalences and Preorders. In _Computer Aided Verification, 3rd_
_International Workshop, CAV ’91, Aalborg, Denmark, July, 1-4, 1991, Proceedings_
_(Lecture Notes in Computer Science, Vol. 575)_, Kim Guldstrand Larsen and Arne
[Skou (Eds.). Springer, 181–191. https://doi.org/10.1007/3-540-55179-4_18](https://doi.org/10.1007/3-540-55179-4_18)

[14] Zhaohui Fu and Sharad Malik. 2006. On Solving the Partial MAX-SAT Problem.
In _Theory and Applications of Satisfiability Testing - SAT 2006, 9th International_
_Conference, Seattle, WA, USA, August 12-15, 2006, Proceedings (Lecture Notes in_
_Computer Science, Vol. 4121)_, Armin Biere and Carla P. Gomes (Eds.). Springer,
[252–265. https://doi.org/10.1007/11814948_25](https://doi.org/10.1007/11814948_25)

[15] Georgios Giantamidis, Stavros Tripakis, and Stylianos Basagiannis. 2021. Learning Moore machines from input-output traces. _Int. J. Softw. Tools Technol. Transf._
[23, 1 (2021), 1–29. https://doi.org/10.1007/s10009-019-00544-0](https://doi.org/10.1007/s10009-019-00544-0)

[16] E. Mark Gold. 1978. Complexity of Automaton Identification from Given Data.
_Inf. Control._ [37, 3 (1978), 302–320. https://doi.org/10.1016/S0019-9958(78)90562-4](https://doi.org/10.1016/S0019-9958(78)90562-4)

[17] Olga Grinchtein, Martin Leucker, and Nir Piterman. 2006. Inferring Network
Invariants Automatically. In _Automated Reasoning, Third International Joint Con-_
_ference, IJCAR 2006, Seattle, WA, USA, August 17-20, 2006, Proceedings (Lecture_
_Notes in Computer Science, Vol. 4130)_, Ulrich Furbach and Natarajan Shankar
[(Eds.). Springer, 483–497. https://doi.org/10.1007/11814771_40](https://doi.org/10.1007/11814771_40)

[18] Roland Groz, Nicolas Brémond, Adenilso Simao, and Catherine Oriat. 2020. hWinference: A heuristic approach to retrieve models through black box testing.
_Journal of Systems and Software_ [159 (2020), 110426. https://doi.org/10.1016/j.jss.](https://doi.org/10.1016/j.jss.2019.110426)
[2019.110426](https://doi.org/10.1016/j.jss.2019.110426)

[19] Marijn Heule and Sicco Verwer. 2013. Software model synthesis using satisfiability
solvers. _Empir. Softw. Eng._ [18, 4 (2013), 825–856. https://doi.org/10.1007/s10664-](https://doi.org/10.1007/s10664-012-9222-z)
[012-9222-z](https://doi.org/10.1007/s10664-012-9222-z)

[20] Alexey Ignatiev, Antonio Morgado, and Joao Marques-Silva. 2018. PySAT: A
Python Toolkit for Prototyping with SAT Oracles. In _SAT_ . 428–437. [https:](https://doi.org/10.1007/978-3-319-94144-8_26)
[//doi.org/10.1007/978-3-319-94144-8_26](https://doi.org/10.1007/978-3-319-94144-8_26)

[21] Alexey Ignatiev, António Morgado, and João Marques-Silva. 2019. RC2: an
Efficient MaxSAT Solver. _J. Satisf. Boolean Model. Comput._ 11, 1 (2019), 53–64.
[https://doi.org/10.3233/SAT190116](https://doi.org/10.3233/SAT190116)

[22] Michael J. Kearns. 1998. Efficient Noise-Tolerant Learning from Statistical Queries.
_J. ACM_ [45, 6 (1998), 983–1006. https://doi.org/10.1145/293347.293351](https://doi.org/10.1145/293347.293351)

[23] Igor Khmelnitsky, Serge Haddad, Lina Ye, Benoît Barbot, Benedikt Bollig, Martin Leucker, Daniel Neider, and Rajarshi Roy. 2022. Analyzing Robustness of
Angluin’s L* Algorithm in Presence of Noise. In _Proceedings of the 13th Interna-_
_tional Symposium on Games, Automata, Logics and Formal Verification, GandALF_
_2022, Madrid, Spain, September 21-23, 2022 (EPTCS, Vol. 370)_, Pierre Ganty and
[Dario Della Monica (Eds.). 81–96. https://doi.org/10.4204/EPTCS.370.6](https://doi.org/10.4204/EPTCS.370.6)

[24] Iraklis A. Klampanos. 2009. Manning Christopher, Prabhakar Raghavan, Hinrich
Schütze: Introduction to information retrieval. _Inf. Retr._ 12, 5 (2009), 609–612.
[https://doi.org/10.1007/s10791-009-9096-x](https://doi.org/10.1007/s10791-009-9096-x)

[25] Mark W. Krentel. 1988. The Complexity of Optimization Problems. _J. Comput._
_Syst. Sci._ [36, 3 (1988), 490–509. https://doi.org/10.1016/0022-0000(88)90039-6](https://doi.org/10.1016/0022-0000(88)90039-6)

[26] Frédéric Lardeux and Éric Monfroy. 2021. Improved SAT Models for NFA Learning.
In _Optimization and Learning - 4th International Conference, OLA 2021, Catania,_
_Italy, June 21-23, 2021, Proceedings (Communications in Computer and Information_
_Science, Vol. 1443)_, Bernabé Dorronsoro, Lionel Amodeo, Mario Pavone, and
[Patricia Ruiz (Eds.). Springer, 267–279. https://doi.org/10.1007/978-3-030-85672-](https://doi.org/10.1007/978-3-030-85672-4_20)
[4_20](https://doi.org/10.1007/978-3-030-85672-4_20)

[27] Simon M. Lucas and T. Jeff Reynolds. 2005. Learning Deterministic Finite Automata with a Smart State Labeling Evolutionary Algorithm. _IEEE Trans. Pattern_
_Anal. Mach. Intell._ [27, 7 (2005), 1063–1074. https://doi.org/10.1109/TPAMI.2005.](https://doi.org/10.1109/TPAMI.2005.143)
[143](https://doi.org/10.1109/TPAMI.2005.143)

[28] Chen Luo, Fei He, and Carlo Ghezzi. 2017. Inferring software behavioral models
with MapReduce. _Sci. Comput. Program._ [145 (2017), 13–36. https://doi.org/10.](https://doi.org/10.1016/j.scico.2017.04.004)
[1016/j.scico.2017.04.004](https://doi.org/10.1016/j.scico.2017.04.004)




[29] Vasco M. Manquinho, João P. Marques Silva, and Jordi Planes. 2009. Algorithms
for Weighted Boolean Optimization. In _Theory and Applications of Satisfiability_
_Testing - SAT 2009, 12th International Conference, SAT 2009, Swansea, UK, June 30_

_- July 3, 2009. Proceedings (Lecture Notes in Computer Science, Vol. 5584)_, Oliver
[Kullmann (Ed.). Springer, 495–508. https://doi.org/10.1007/978-3-642-02777-2_45](https://doi.org/10.1007/978-3-642-02777-2_45)

[30] Hua Mao, Yingke Chen, Manfred Jaeger, Thomas D. Nielsen, Kim G. Larsen,
and Brian Nielsen. 2016. Learning deterministic probabilistic automata from
a model checking perspective. _Mach. Learn._ 105, 2 (2016), 255–299. [https:](https://doi.org/10.1007/s10994-016-5565-9)
[//doi.org/10.1007/s10994-016-5565-9](https://doi.org/10.1007/s10994-016-5565-9)

[31] Leonardo Mariani, Mauro Pezzè, and Mauro Santoro. 2017. GK-Tail+ An Efficient
Approach to Learn Software Models. _IEEE Trans. Software Eng._ 43, 8 (2017),
[715–738. https://doi.org/10.1109/TSE.2016.2623623](https://doi.org/10.1109/TSE.2016.2623623)

[32] Ruben Martins, Saurabh Joshi, Vasco M. Manquinho, and Inês Lynce. 2014. Incremental Cardinality Constraints for MaxSAT. In _Principles and Practice of Con-_
_straint Programming - 20th International Conference, CP 2014, Lyon, France, Sep-_
_tember 8-12, 2014. Proceedings (Lecture Notes in Computer Science, Vol. 8656)_, Barry
[O’Sullivan (Ed.). Springer, 531–548. https://doi.org/10.1007/978-3-319-10428-](https://doi.org/10.1007/978-3-319-10428-7_39)
[7_39](https://doi.org/10.1007/978-3-319-10428-7_39)

[33] Edward F. Moore. 2016. Gedanken-experiments on sequential machines. In
_Automata Studies. (AM-34), Volume 34_, C. E. Shannon and J. McCarthy (Eds.).
[Princeton University Press, 129–154. https://doi.org/doi:10.1515/9781400882618-](https://doi.org/doi:10.1515/9781400882618-006)
[006](https://doi.org/doi:10.1515/9781400882618-006)

[34] António Morgado, Carmine Dodaro, and João Marques-Silva. 2014. Core-Guided
MaxSAT with Soft Cardinality Constraints. In _Principles and Practice of Constraint_
_Programming - 20th International Conference, CP 2014, Lyon, France, Septem-_
_ber 8-12, 2014. Proceedings (Lecture Notes in Computer Science, Vol. 8656)_, Barry
[O’Sullivan (Ed.). Springer, 564–573. https://doi.org/10.1007/978-3-319-10428-](https://doi.org/10.1007/978-3-319-10428-7_41)
[7_41](https://doi.org/10.1007/978-3-319-10428-7_41)

[35] António Morgado, Federico Heras, Mark H. Liffiton, Jordi Planes, and João
Marques-Silva. 2013. Iterative and core-guided MaxSAT solving: A survey and
assessment. _Constraints An Int. J._ [18, 4 (2013), 478–534. https://doi.org/10.1007/](https://doi.org/10.1007/s10601-013-9146-2)
[s10601-013-9146-2](https://doi.org/10.1007/s10601-013-9146-2)

[36] António Morgado, Alexey Ignatiev, and João Marques-Silva. 2014. MSCG: Robust
Core-Guided MaxSAT Solving. _J. Satisf. Boolean Model. Comput._ 9, 1 (2014),
[129–134. https://doi.org/10.3233/sat190105](https://doi.org/10.3233/sat190105)

[37] Edi Muskardin, Martin Tappler, Bernhard K. Aichernig, and Ingo Pill. 2022. Reinforcement Learning under Partial Observability Guided by Learned Environment
Models. _CoRR_ [abs/2206.11708 (2022). https://doi.org/10.48550/arXiv.2206.11708](https://doi.org/10.48550/arXiv.2206.11708)
[arXiv:2206.11708](https://arxiv.org/abs/2206.11708)

[38] Edi Muškardin, Bernhard Aichernig, Ingo Pill, Andrea Pferscher, and Martin
Tappler. 2022. AALpy: an active automata learning library. _Innovations in Systems_
_and Software Engineering_ [18 (03 2022), 1–10. https://doi.org/10.1007/s11334-022-](https://doi.org/10.1007/s11334-022-00449-3)
[00449-3](https://doi.org/10.1007/s11334-022-00449-3)

[39] Daniel Neider. 2012. Computing Minimal Separating DFAs and Regular Invariants
Using SAT and SMT Solvers. In _Automated Technology for Verification and Analysis_

_- 10th International Symposium, ATVA 2012, Thiruvananthapuram, India, October_
_3-6, 2012. Proceedings (Lecture Notes in Computer Science, Vol. 7561)_, Supratik
[Chakraborty and Madhavan Mukund (Eds.). Springer, 354–369. https://doi.org/](https://doi.org/10.1007/978-3-642-33386-6_28)
[10.1007/978-3-642-33386-6_28](https://doi.org/10.1007/978-3-642-33386-6_28)

[40] Nordic Semiconductor. Nov. 2021. _nRF52832 Product Specification v1.8_ .

[41] Jose Oncina and Pedro Garcia. 1992. Identifying Regular Languages In Polynomial
Time. In _Advances in Structual and Syntactic Pattern Recognition, Volume 5 of_
_Series in Machine Perception and Artificial Intelligence_ . World Scientific, 99–108.

[42] Andrea Pferscher and Bernhard K. Aichernig. 2021. ble-learning: Fingerprinting
Bluetooth Low Energy via Active Automata Learning. [https://github.com/](https://github.com/apferscher/ble-learning)
[apferscher/ble-learning, accessed on March 14, 2023.](https://github.com/apferscher/ble-learning)

[43] Andrea Pferscher and Bernhard K. Aichernig. 2021. Fingerprinting Bluetooth
Low Energy Devices via Active Automata Learning. In _Formal Methods - 24th In-_
_ternational Symposium, FM 2021, Virtual Event, November 20-26, 2021, Proceedings_
_(Lecture Notes in Computer Science, Vol. 13047)_, Marieke Huisman, Corina S. Pasare[anu, and Naijun Zhan (Eds.). Springer, 524–542. https://doi.org/10.1007/978-3-](https://doi.org/10.1007/978-3-030-90870-6_28)
[030-90870-6_28](https://doi.org/10.1007/978-3-030-90870-6_28)

[44] Raphaël Reynouard, Anna Ingólfsdóttir, and Giovanni Bacci. 2023. Jajapy: a
learning library for stochastic models. In _Quantitative Evaluation of Systems -_
_20th International Conference, QEST 2023, Antwerp, Belgium, September 18-23, 2023,_
_Proceedings (Lecture Notes in Computer Science)_, Nils Jansen Mirco Tribastone
(Ed.). Springer.

[45] Marc Sebban and Jean-Christophe Janodet. 2003. On State Merging in Grammatical Inference: A Statistical Approach for Dealing with Noisy Data. In _Machine_
_Learning, Proceedings of the Twentieth International Conference (ICML 2003), Au-_
_gust 21-24, 2003, Washington, DC, USA_, Tom Fawcett and Nina Mishra (Eds.).
[AAAI Press, 688–695. http://www.aaai.org/Library/ICML/2003/icml03-090.php](http://www.aaai.org/Library/ICML/2003/icml03-090.php)

[46] Rick Smetsers, Paul Fiterau-Brostean, and Frits W. Vaandrager. 2018. Model
Learning as a Satisfiability Modulo Theories Problem. In _Language and Automata_
_Theory and Applications - 12th International Conference, LATA 2018, Ramat Gan,_
_Israel, April 9-11, 2018, Proceedings (Lecture Notes in Computer Science, Vol. 10792)_,
Shmuel Tomi Klein, Carlos Martín-Vide, and Dana Shapira (Eds.). Springer, 182–
[194. https://doi.org/10.1007/978-3-319-77313-1_14](https://doi.org/10.1007/978-3-319-77313-1_14)


It’s Not a Feature, It’s a Bug ICSE ’24, April 14–20, 2024, Lisbon, Portugal




[47] Martin Tappler, Bernhard K. Aichernig, and Florian Lorber. 2022. Timed Automata
Learning via SMT Solving. In _NASA Formal Methods - 14th International Sympo-_
_sium, NFM 2022, Pasadena, CA, USA, May 24-27, 2022, Proceedings (Lecture Notes in_
_Computer Science, Vol. 13260)_, Jyotirmoy V. Deshmukh, Klaus Havelund, and Ivan
[Perez (Eds.). Springer, 489–507. https://doi.org/10.1007/978-3-031-06773-0_26](https://doi.org/10.1007/978-3-031-06773-0_26)

[48] Martin Tappler, Edi Muskardin, Bernhard K. Aichernig, and Bettina Könighofer.
2023. Learning Environment Models with Continuous Stochastic Dynamics. _CoRR_ abs/2306.17204 (2023). [https://doi.org/10.48550/arXiv.2306.17204](https://doi.org/10.48550/arXiv.2306.17204)
[arXiv:2306.17204](https://arxiv.org/abs/2306.17204)

[49] Vladimir Ulyantsev, Ilya Zakirzyanov, and Anatoly Shalyto. 2015. BFS-Based
Symmetry Breaking Predicates for DFA Identification. In _Language and Automata_
_Theory and Applications - 9th International Conference, LATA 2015, Nice, France,_
_March 2-6, 2015, Proceedings (Lecture Notes in Computer Science, Vol. 8977)_, AdrianHoria Dediu, Enrico Formenti, Carlos Martín-Vide, and Bianca Truthe (Eds.).
[Springer, 611–622. https://doi.org/10.1007/978-3-319-15579-1_48](https://doi.org/10.1007/978-3-319-15579-1_48)




[50] M. P. Vasilevskii. 1973. Failure diagnosis of automata. _Cybernetics_ 9, 4 (01 Jul
[1973), 653–665. https://doi.org/10.1007/BF01068590](https://doi.org/10.1007/BF01068590)

[51] Manuel Vázquez de Parga, Pedro García, and José Ruiz. 2006. A Family of
Algorithms for Non Deterministic Regular Languages Inference. In _Implemen-_
_tation and Application of Automata, 11th International Conference, CIAA 2006,_
_Taipei, Taiwan, August 21-23, 2006, Proceedings (Lecture Notes in Computer Sci-_
_ence, Vol. 4094)_, Oscar H. Ibarra and Hsu-Chun Yen (Eds.). Springer, 265–274.
[https://doi.org/10.1007/11812128_25](https://doi.org/10.1007/11812128_25)

[52] Neil Walkinshaw, Ramsay Taylor, and John Derrick. 2016. Inferring extended
finite state machine models from software executions. _Empir. Softw. Eng._ 21, 3
[(2016), 811–853. https://doi.org/10.1007/s10664-015-9367-7](https://doi.org/10.1007/s10664-015-9367-7)

[53] Felix Wallner, Bernhard K. Aichernig, and Christian Burghard. 2023. _PMSAT_
_Inference Algorithm and Publication Artifacts_ [. https://doi.org/10.5281/zenodo.](https://doi.org/10.5281/zenodo.8341541)
[8341541](https://doi.org/10.5281/zenodo.8341541)


