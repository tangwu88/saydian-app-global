import { Eb1Frame, Eb1FrameBuffer, Eb1ResponseCollector } from '../model/UrionEb1Protocol';

interface PendingCommand {
  command: number; collector: Eb1ResponseCollector; timer: number;
  resolve: (frames: Eb1Frame[]) => void; reject: (error: Error) => void;
}
export class UrionCommandChannel {
  private generation: number = 0;
  private queue: Promise<void> = Promise.resolve();
  private buffer: Eb1FrameBuffer = new Eb1FrameBuffer();
  private pending: PendingCommand | undefined = undefined;
  private write: (bytes: number[]) => Promise<void>;
  private stalled: () => void;
  private notification: (frame: Eb1Frame) => void;
  private timeoutMs: number;
  constructor(write: (bytes: number[]) => Promise<void>, stalled: () => void,
    notification: (frame: Eb1Frame) => void, timeoutMs: number = 8000) {
    this.write = write; this.stalled = stalled; this.notification = notification; this.timeoutMs = timeoutMs;
  }
  session(): number { return this.generation; }
  retire(): void {
    ++this.generation; this.buffer.reset();
    const pending = this.pending; this.pending = undefined;
    if (pending) { clearTimeout(pending.timer); pending.reject(new Error('Urion connection retired')); }
  }
  receive(bytes: number[], generation: number): void {
    if (generation !== this.generation) return;
    for (const frame of this.buffer.add(bytes)) {
      if (generation !== this.generation) return;
      const pending = this.pending;
      if (!pending || (frame.command !== pending.command && frame.command !== (pending.command | 0x80))) {
        this.notification(frame); continue;
      }
      if (frame.isError) {
        this.finish(undefined, new Error(frame.isUnsupported ? 'Urion unsupported command' : 'Urion command rejected'));
        continue;
      }
      try {
        const result = pending.collector.add(frame);
        if (result) this.finish(result);
      } catch {
        this.retire(); this.stalled();
      }
    }
  }
  exchange(command: number, payload: number[] = [], count: number = 1): Promise<Eb1Frame[]> {
    const frame = Eb1Frame.request(command, payload);
    const collector = new Eb1ResponseCollector(command, count);
    const generation = this.generation;
    const operation = async (): Promise<Eb1Frame[]> => {
      if (generation !== this.generation) throw new Error('Urion connection changed');
      return new Promise<Eb1Frame[]>((resolve, reject) => {
        const timer = setTimeout(() => {
          if (generation !== this.generation) return;
          this.retire(); this.stalled();
        }, this.timeoutMs);
        this.pending = { command: command, collector: collector, timer: timer, resolve: resolve, reject: reject };
        this.write(frame.bytes).catch((error: Error) => {
          if (generation !== this.generation) return;
          this.retire(); this.stalled();
        });
      });
    };
    const result = this.queue.then(operation, operation);
    this.queue = result.then(() => {}, () => {});
    return result;
  }
  private finish(frames?: Eb1Frame[], error?: Error): void {
    const pending = this.pending; this.pending = undefined;
    if (!pending) return;
    clearTimeout(pending.timer);
    if (error) pending.reject(error); else pending.resolve(frames ?? []);
  }
}
