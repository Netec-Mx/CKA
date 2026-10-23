#!/usr/bin/env node

import {
  readFile,
} from 'node:fs/promises';

import {
  resolve,
} from 'node:path';

import vm from 'node:vm';

const PROGRESS_PATH =
  resolve(
    process.cwd(),
    'assets',
    'js',
    'lab-progress.js',
  );

const progressSource =
  await readFile(
    PROGRESS_PATH,
    'utf8',
  );

let passed = 0;
let failed = 0;

function assert(
  condition,
  message,
) {
  if (!condition) {
    throw new Error(
      message,
    );
  }
}

async function test(
  name,
  callback,
) {
  try {
    await callback();

    console.log(
      `✓ ${name}`,
    );

    passed += 1;
  } catch (error) {
    console.error(
      `✗ ${name}`,
    );

    console.error(
      error instanceof Error
        ? error.stack ??
          error.message
        : String(
            error,
          ),
    );

    failed += 1;
  }
}

class MemoryStorage {
  constructor(
    initial = {},
  ) {
    this.values =
      new Map(
        Object.entries(
          initial,
        ),
      );
  }

  getItem(
    key,
  ) {
    return this.values.has(
      key,
    )
      ? this.values.get(
          key,
        )
      : null;
  }

  setItem(
    key,
    value,
  ) {
    this.values.set(
      key,
      String(
        value,
      ),
    );
  }

  removeItem(
    key,
  ) {
    this.values.delete(
      key,
    );
  }
}

class FakeClassList {
  toggle() {}
  add() {}
  remove() {}
}

class FakeStep {
  constructor(
    taskId,
    stepId,
  ) {
    this.dataset = {
      taskId,
      stepId,
      stepNumber:
        stepId,
    };

    this.classList =
      new FakeClassList();

    this.attributes =
      new Map();

    this.listeners =
      new Map();
  }

  addEventListener(
    type,
    listener,
  ) {
    this.listeners.set(
      type,
      listener,
    );
  }

  setAttribute(
    name,
    value,
  ) {
    this.attributes.set(
      name,
      String(
        value,
      ),
    );
  }

  focus() {}

  closest() {
    return {
      classList:
        new FakeClassList(),

      scrollIntoView() {},
    };
  }
}

class FakeEventTarget {
  constructor() {
    this.listeners =
      new Map();
  }

  addEventListener(
    type,
    listener,
  ) {
    if (
      !this.listeners.has(
        type,
      )
    ) {
      this.listeners.set(
        type,
        [],
      );
    }

    this.listeners
      .get(
        type,
      )
      .push(
        listener,
      );
  }

  dispatchEvent(
    event,
  ) {
    const listeners =
      this.listeners.get(
        event.type,
      ) ?? [];

    for (
      const listener
      of listeners
    ) {
      listener.call(
        this,
        event,
      );
    }
  }
}

class FakeCustomEvent {
  constructor(
    type,
    options = {},
  ) {
    this.type =
      type;

    this.detail =
      options.detail;
  }
}

function createPanel() {
  const elements =
    new Map();

  return {
    classList:
      new FakeClassList(),

    style: {
      removeProperty() {},
    },

    setAttribute() {},

    querySelector(
      selector,
    ) {
      if (
        !elements.has(
          selector,
        )
      ) {
        elements.set(
          selector,
          {
            textContent:
              '',

            disabled:
              false,

            title:
              '',

            style: {},

            classList:
              new FakeClassList(),

            setAttribute() {},

            addEventListener() {},
          },
        );
      }

      return elements.get(
        selector,
      );
    },
  };
}

function createBrowser({
  courseId,
  labId = 'l001',
  localStorage,
} = {}) {
  const document =
    new FakeEventTarget();

  const window =
    new FakeEventTarget();

  const steps = [
    new FakeStep(
      't001',
      's001',
    ),
    new FakeStep(
      't001',
      's002',
    ),
  ];

  const root = {
    dataset: {
      courseId,
      labId,
    },

    querySelectorAll(
      selector,
    ) {
      if (
        selector ===
        '.step-label[data-step-id]'
      ) {
        return steps;
      }

      return [];
    },
  };

  const panel =
    createPanel();

  document.readyState =
    'complete';

  document.body = {
    appendChild() {},
  };

  document.querySelector =
    selector => {
      if (
        selector ===
        'article.lab'
      ) {
        return root;
      }

      if (
        selector ===
        '.lab-progress'
      ) {
        return panel;
      }

      return null;
    };

  document.createElement =
    () =>
      panel;

  window.location = {
    pathname:
      '/lab1/lab1/',
  };

  window.innerHeight =
    1000;

  window.matchMedia =
    () => ({
      matches:
        false,
    });

  window.setTimeout =
    setTimeout;

  window.clearTimeout =
    clearTimeout;

  const context =
    vm.createContext({
      console,

      document,
      window,

      localStorage,

      CustomEvent:
        FakeCustomEvent,

      JSON,
      Date,
      Array,
      Set,

      setTimeout,
      clearTimeout,
    });

  vm.runInContext(
    progressSource,
    context,
    {
      filename:
        PROGRESS_PATH,
    },
  );

  return {
    document,
    window,
    steps,
  };
}

const STORAGE_PREFIX =
  'netec:stepProgress:';

await test(
  'migra una sola vez la clave legacy al scope courseId + labId',
  async () => {
    const legacyKey =
      `${STORAGE_PREFIX}l001`;

    const scopedKey =
      `${STORAGE_PREFIX}` +
      'terraform-aws-essentials:' +
      'l001';

    const localStorage =
      new MemoryStorage({
        [legacyKey]:
          JSON.stringify({
            version:
              1,
            completed: [
              's001',
            ],
            updatedAt:
              123,
          }),
      });

    createBrowser({
      courseId:
        'terraform-aws-essentials',
      localStorage,
    });

    assert(
      localStorage.getItem(
        scopedKey,
      ) !==
        null,
      'La clave scoped no fue creada.',
    );

    assert(
      localStorage.getItem(
        legacyKey,
      ) ===
        null,
      'La clave legacy no fue eliminada después de migrar.',
    );

    const migrated =
      JSON.parse(
        localStorage.getItem(
          scopedKey,
        ),
      );

    assert(
      migrated.completed.length ===
        1 &&
        migrated.completed[0] ===
          's001',
      'El progreso legacy no fue preservado.',
    );
  },
);

await test(
  'dos cursos con l001 mantienen progreso aislado',
  async () => {
    const localStorage =
      new MemoryStorage();

    const courseAKey =
      `${STORAGE_PREFIX}` +
      'course-a:l001';

    const courseBKey =
      `${STORAGE_PREFIX}` +
      'course-b:l001';

    createBrowser({
      courseId:
        'course-a',
      localStorage,
    });

    const courseAState = {
      version:
        1,
      completed: [
        's001',
      ],
      updatedAt:
        Date.now(),
    };

    localStorage.setItem(
      courseAKey,
      JSON.stringify(
        courseAState,
      ),
    );

    createBrowser({
      courseId:
        'course-b',
      localStorage,
    });

    const courseBState = {
      version:
        1,
      completed: [
        's002',
      ],
      updatedAt:
        Date.now(),
    };

    localStorage.setItem(
      courseBKey,
      JSON.stringify(
        courseBState,
      ),
    );

    const storedA =
      JSON.parse(
        localStorage.getItem(
          courseAKey,
        ),
      );

    const storedB =
      JSON.parse(
        localStorage.getItem(
          courseBKey,
        ),
      );

    assert(
      storedA.completed.length ===
        1 &&
        storedA.completed[0] ===
          's001',
      'El progreso de course-a fue alterado.',
    );

    assert(
      storedB.completed.length ===
        1 &&
        storedB.completed[0] ===
          's002',
      'El progreso de course-b fue alterado.',
    );

    assert(
      courseAKey !==
        courseBKey,
      'Los cursos no deben compartir la misma clave.',
    );
  },
);

console.log(
  `\nTests: ${passed} passed, ${failed} failed`,
);

if (
  failed > 0
) {
  process.exitCode =
    1;
}
